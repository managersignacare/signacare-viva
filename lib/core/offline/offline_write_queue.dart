import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';

/// Audit Tier 4.1 (HIGH-J3) — persistent write queue for Viva vitals
/// and other patient-tracking POSTs that would otherwise be silently
/// swallowed by `catch (_) {}` blocks when the device is offline.
///
/// Design:
///   - enqueue(method, path, body) persists to SharedPreferences so
///     data survives app restarts.
///   - flush() attempts every pending entry against pApi. Successful
///     entries are dropped; DioException on network error (no response)
///     retains the entry and bumps retryCount with exponential backoff
///     (30s / 2m / 10m). After `maxRetries` the entry is marked
///     FAILED_PERMANENT and surfaced to the caller via the listener.
///   - A failed HTTP response (4xx/5xx) is treated as permanent — the
///     body is malformed or rejected and retrying won't help.
///   - Listener callbacks (onChange) let UI surfaces show the pending
///     count / failed count.
///
/// Not included (explicit scope):
///   - No dedicated connectivity stream (connectivity_plus is NOT in
///     pubspec). The queue is flushed opportunistically on app resume
///     and on every new enqueue attempt. Adding connectivity_plus as
///     a plugin would require iOS + Android native channel wiring and
///     is out of scope for Tier 4.1.
///   - No SQLite fallback; SharedPreferences handles the small queue
///     (<1 KB per entry, expected queue size < 50 entries).
class OfflineWriteQueue {
  OfflineWriteQueue._();
  static final OfflineWriteQueue instance = OfflineWriteQueue._();

  static const _kQueueKey = 'viva_offline_write_queue_v1';
  static const int _maxRetries = 3;
  // Exponential backoff milestones in seconds: 30s, 2m, 10m.
  static const List<int> _backoffSeconds = [30, 120, 600];

  final List<VoidCallback> _listeners = [];
  List<OfflineEntry>? _cache;

  void addListener(VoidCallback fn) => _listeners.add(fn);
  void removeListener(VoidCallback fn) => _listeners.remove(fn);

  void _notify() {
    for (final fn in List.of(_listeners)) {
      try { fn(); } catch (_) {}
    }
  }

  Future<List<OfflineEntry>> _load() async {
    if (_cache != null) return _cache!;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kQueueKey);
    if (raw == null || raw.isEmpty) {
      _cache = [];
      return _cache!;
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      _cache = list
          .map((e) => OfflineEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      return _cache!;
    } catch (_) {
      // Corrupt queue — drop it rather than crash on every app launch.
      _cache = [];
      return _cache!;
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_cache!.map((e) => e.toJson()).toList());
    await prefs.setString(_kQueueKey, encoded);
  }

  /// Enqueue a write for later retry. Call this ONLY after catching a
  /// DioException that indicates a transport-level failure (no
  /// response from the server); 4xx / 5xx replies indicate the request
  /// was delivered and should not be queued.
  Future<void> enqueue({
    required String method,
    required String path,
    required Map<String, dynamic> body,
  }) async {
    final entries = await _load();
    entries.add(OfflineEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      method: method,
      path: path,
      body: body,
      createdAt: DateTime.now().toUtc(),
      retryCount: 0,
      status: OfflineStatus.pending,
    ));
    await _persist();
    _notify();
  }

  /// Attempt to flush every pending entry that is past its backoff
  /// window. Returns the number of entries successfully delivered.
  Future<int> flush() async {
    final entries = await _load();
    if (entries.isEmpty) return 0;

    final now = DateTime.now().toUtc();
    int delivered = 0;
    final keep = <OfflineEntry>[];

    for (final e in entries) {
      if (e.status == OfflineStatus.failedPermanent) {
        keep.add(e);
        continue;
      }
      // Respect backoff window
      final backoffIdx = e.retryCount.clamp(0, _backoffSeconds.length - 1);
      final nextAttempt = e.createdAt.add(
        Duration(seconds: _backoffSeconds[backoffIdx]),
      );
      if (e.retryCount > 0 && now.isBefore(nextAttempt)) {
        keep.add(e);
        continue;
      }

      try {
        await _dispatch(e);
        delivered += 1;
        // successful — do not keep
      } on DioException catch (err) {
        final isTransport = err.response == null;
        if (isTransport && e.retryCount + 1 < _maxRetries) {
          keep.add(e.bumpRetry());
        } else {
          keep.add(e.markPermanent(err.message ?? 'unknown'));
        }
      } catch (err) {
        keep.add(e.markPermanent(err.toString()));
      }
    }

    _cache = keep;
    await _persist();
    _notify();
    return delivered;
  }

  Future<void> _dispatch(OfflineEntry e) async {
    // pApi exposes get / post / patch / delete only — PUT is not part
    // of Viva's API surface. Keep the switch strict so a rogue
    // enqueue('PUT', …) surfaces as a permanent failure instead of a
    // silent drop.
    switch (e.method.toUpperCase()) {
      case 'POST':
        await pApi.post(e.path, data: e.body);
        return;
      case 'PATCH':
        await pApi.patch(e.path, data: e.body);
        return;
      default:
        throw StateError('Unsupported offline method: ${e.method}');
    }
  }

  Future<List<OfflineEntry>> snapshot() async => List.of(await _load());

  Future<int> pendingCount() async {
    final rows = await _load();
    return rows.where((e) => e.status != OfflineStatus.failedPermanent).length;
  }

  Future<int> failedCount() async {
    final rows = await _load();
    return rows.where((e) => e.status == OfflineStatus.failedPermanent).length;
  }
}

enum OfflineStatus { pending, failedPermanent }

class OfflineEntry {
  final String id;
  final String method;
  final String path;
  final Map<String, dynamic> body;
  final DateTime createdAt;
  final int retryCount;
  final OfflineStatus status;
  final String? failureReason;

  OfflineEntry({
    required this.id,
    required this.method,
    required this.path,
    required this.body,
    required this.createdAt,
    required this.retryCount,
    required this.status,
    this.failureReason,
  });

  OfflineEntry bumpRetry() => OfflineEntry(
        id: id,
        method: method,
        path: path,
        body: body,
        createdAt: createdAt,
        retryCount: retryCount + 1,
        status: status,
        failureReason: failureReason,
      );

  OfflineEntry markPermanent(String reason) => OfflineEntry(
        id: id,
        method: method,
        path: path,
        body: body,
        createdAt: createdAt,
        retryCount: retryCount,
        status: OfflineStatus.failedPermanent,
        failureReason: reason,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'method': method,
        'path': path,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
        'retryCount': retryCount,
        'status': status.name,
        if (failureReason != null) 'failureReason': failureReason,
      };

  static OfflineEntry fromJson(Map<String, dynamic> j) => OfflineEntry(
        id: j['id'] as String,
        method: j['method'] as String,
        path: j['path'] as String,
        body: Map<String, dynamic>.from(j['body'] as Map),
        createdAt: DateTime.parse(j['createdAt'] as String).toUtc(),
        retryCount: (j['retryCount'] as num).toInt(),
        status: OfflineStatus.values
            .firstWhere((s) => s.name == j['status'], orElse: () => OfflineStatus.pending),
        failureReason: j['failureReason'] as String?,
      );
}
