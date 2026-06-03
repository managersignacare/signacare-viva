// apps/patient-app/lib/core/services/sync_client.dart
//
// Phase 11B — Viva's mobile delta sync client.
//
// Mirror of Sara's SyncClient. Hits /api/v1/patient-app/mobile-sync
// which respects the patient's per-module opt-in from
// patient_sync_preferences. Cache persisted in SharedPreferences
// as JSON so the app renders instantly on cold-start and works
// offline against the last snapshot.
//
// The payload shape is wider than Sara's (notifications +
// appointments + outreachLog) because Viva surfaces more sections.
// Clients that only care about one section read the relevant
// `ValueNotifier` slice; the rest is ignored.
//
// Coexistence rule: does NOT replace the existing
// sync_settings_screen.dart upstream tracking sync. Different
// direction (clinic → device), different endpoint, different
// persistence key.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import 'document_cache.dart';
import 'local_reminder_scheduler.dart';

const _kVivaSyncCacheKey = 'viva_downstream_sync_cache_v1';
const _kVivaSyncCursorKey = 'viva_downstream_sync_cursor_v1';

class VivaSyncSnapshot {
  const VivaSyncSnapshot({
    required this.notifications,
    required this.appointments,
    required this.outreachLog,
    required this.documents,
    required this.preferencesSnapshot,
    required this.lastSyncAt,
  });

  final List<Map<String, dynamic>> notifications;
  final List<Map<String, dynamic>> appointments;
  final List<Map<String, dynamic>> outreachLog;
  final List<Map<String, dynamic>> documents;
  final Map<String, bool> preferencesSnapshot;
  final DateTime lastSyncAt;

  Map<String, dynamic> toJson() => {
        'notifications': notifications,
        'appointments': appointments,
        'outreachLog': outreachLog,
        'documents': documents,
        'preferencesSnapshot': preferencesSnapshot,
        'lastSyncAt': lastSyncAt.toIso8601String(),
      };

  static VivaSyncSnapshot fromJson(Map<String, dynamic> j) {
    List<Map<String, dynamic>> toList(dynamic v) =>
        ((v as List?) ?? const [])
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
    final prefRaw = (j['preferencesSnapshot'] as Map?) ?? const {};
    final prefs = <String, bool>{};
    prefRaw.forEach((k, v) { if (v is bool) prefs[k.toString()] = v; });
    final ts = j['lastSyncAt'] as String?;
    return VivaSyncSnapshot(
      notifications: toList(j['notifications']),
      appointments: toList(j['appointments']),
      outreachLog: toList(j['outreachLog']),
      documents: toList(j['documents']),
      preferencesSnapshot: prefs,
      lastSyncAt: ts != null ? DateTime.tryParse(ts) ?? DateTime.now() : DateTime.now(),
    );
  }
}

final vivaSyncClientProvider = Provider<VivaSyncClient>((ref) => VivaSyncClient(
      documentCache: ref.read(vivaDocumentCacheProvider),
      reminderScheduler: ref.read(vivaLocalReminderSchedulerProvider),
    ));

class VivaSyncClient {
  VivaSyncClient({
    required this.documentCache,
    required this.reminderScheduler,
  });

  final VivaDocumentCache documentCache;
  final VivaLocalReminderScheduler reminderScheduler;

  final ValueNotifier<VivaSyncSnapshot?> snapshot = ValueNotifier<VivaSyncSnapshot?>(null);

  bool _hydrated = false;
  bool _refreshInFlight = false;
  Timer? _periodicTimer;

  Future<void> hydrate() async {
    if (_hydrated) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kVivaSyncCacheKey);
      if (raw != null && raw.isNotEmpty) {
        final map = json.decode(raw) as Map<String, dynamic>;
        snapshot.value = VivaSyncSnapshot.fromJson(map);
      }
    } catch (e) {
      debugPrint('[VivaSyncClient] hydrate failed: $e');
    } finally {
      _hydrated = true;
    }
  }

  Future<VivaSyncSnapshot?> refresh({bool force = false}) async {
    if (_refreshInFlight && !force) return snapshot.value;
    _refreshInFlight = true;
    try {
      await hydrate();
      final prefs = await SharedPreferences.getInstance();
      final cursor = prefs.getString(_kVivaSyncCursorKey);

      final resp = await pApi.get(
        '/patient-app/mobile-sync',
        params: cursor != null ? {'since': cursor} : null,
      );
      if (resp is! Map) return snapshot.value;

      final map = Map<String, dynamic>.from(resp);
      List<Map<String, dynamic>> toList(dynamic v) =>
          ((v as List?) ?? const [])
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList();

      final newNotifications = toList(map['notifications']);
      final newAppointments = toList(map['appointments']);
      final newOutreachLog = toList(map['outreachLog']);
      final newDocuments = toList(map['documents']);
      final prefSnap = <String, bool>{};
      final prefRaw = map['preferencesSnapshot'];
      if (prefRaw is Map) {
        prefRaw.forEach((k, v) { if (v is bool) prefSnap[k.toString()] = v; });
      }
      final lastSyncAt = (map['lastSyncAt'] as String?) ?? DateTime.now().toIso8601String();

      // Merge by id per entity. Appointments + outreach rows with
      // deleted_at != null are treated as tombstones — they're
      // included in the merged list but the UI filters them out.
      List<Map<String, dynamic>> merge(List<Map<String, dynamic>> fresh, List<Map<String, dynamic>> existing) {
        final seen = <String>{};
        final merged = <Map<String, dynamic>>[];
        for (final row in [...fresh, ...existing]) {
          final id = row['id']?.toString();
          if (id == null || seen.contains(id)) continue;
          seen.add(id);
          merged.add(row);
        }
        return merged.length > 500 ? merged.sublist(0, 500) : merged;
      }

      final prev = snapshot.value;
      final effectivePrefs = prefSnap.isEmpty ? (prev?.preferencesSnapshot ?? const {}) : prefSnap;

      // Consent-revocation cleanup: when the server reports a
      // module as disabled (patient toggled the switch off in
      // Sync Settings), we clear the local cache for that module
      // so stale rows don't linger on the device. Pairs with the
      // server-side filter which stops returning new rows for
      // disabled modules. Disabling appointments → within 60s
      // the local list is empty, matching the "tombstone on
      // disable" intent of the Phase 11A design.
      List<Map<String, dynamic>> gate(String moduleKey, List<Map<String, dynamic>> current) {
        return effectivePrefs[moduleKey] == true ? current : const [];
      }

      final fresh = VivaSyncSnapshot(
        notifications: gate('notifications', merge(newNotifications, prev?.notifications ?? const [])),
        appointments: gate('appointments', merge(newAppointments, prev?.appointments ?? const [])),
        outreachLog: gate('reminders', merge(newOutreachLog, prev?.outreachLog ?? const [])),
        documents: gate('documents', merge(newDocuments, prev?.documents ?? const [])),
        // The server-side snapshot of per-module enable flags always
        // wins — it's the source of truth, not a merge.
        preferencesSnapshot: effectivePrefs,
        lastSyncAt: DateTime.tryParse(lastSyncAt) ?? DateTime.now(),
      );
      snapshot.value = fresh;

      await prefs.setString(_kVivaSyncCacheKey, json.encode(fresh.toJson()));
      await prefs.setString(_kVivaSyncCursorKey, lastSyncAt);

      // Phase 11B — fan the fresh delta into the document cache and
      // the on-device reminder scheduler. Both helpers are non-fatal;
      // failures are logged and do not break the sync cycle.
      if (effectivePrefs['documents'] == true) {
        // ignore: discarded_futures
        documentCache.reconcile(fresh.documents);
        final keep = fresh.documents
            .map((d) => d['id']?.toString())
            .whereType<String>()
            .toSet();
        // ignore: discarded_futures
        documentCache.pruneNotIn(keep);
      } else {
        // ignore: discarded_futures
        documentCache.clear();
      }
      if (effectivePrefs['appointments'] == true) {
        // ignore: discarded_futures
        reminderScheduler.rescheduleFromAppointments(fresh.appointments);
      } else {
        // ignore: discarded_futures
        reminderScheduler.cancelAll();
      }

      return fresh;
    } catch (e) {
      debugPrint('[VivaSyncClient] refresh failed (continuing with cached data): $e');
      return snapshot.value;
    } finally {
      _refreshInFlight = false;
    }
  }

  void startPeriodic() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(seconds: 60), (_) => refresh());
  }

  void stopPeriodic() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  Future<void> clear() async {
    stopPeriodic();
    snapshot.value = null;
    _hydrated = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kVivaSyncCacheKey);
      await prefs.remove(_kVivaSyncCursorKey);
    } catch (_) { /* non-fatal */ }
    // Logout wipes the document cache and any pending on-device
    // reminders so a second patient on the same device can't open
    // the previous user's files or receive their reminders.
    try { await documentCache.clear(); } catch (_) { /* non-fatal */ }
    try { await reminderScheduler.cancelAll(); } catch (_) { /* non-fatal */ }
  }
}
