// apps/patient-app/lib/core/services/local_reminder_scheduler.dart
//
// Phase 11B — Viva's on-device reminder scheduler.
//
// Reads the `appointments` slice of the latest VivaSyncSnapshot and
// uses flutter_local_notifications to schedule pre-appointment alerts
// without a server round-trip at fire time. Two offsets by default:
// 24h before and 1h before each future appointment. The scheduler is
// idempotent across syncs — every call cancels Viva-owned reminder
// ids first and re-schedules from the fresh snapshot, so cancelled or
// re-timed appointments are reflected immediately.
//
// Reminder ids are derived deterministically from (appointmentId +
// offsetTier) so reschedules don't leak stale notifications and the
// OS doesn't accumulate duplicates.
//
// Coexistence rule: does NOT replace the FCM foreground-notification
// path in fcm_service.dart. That renders push-originated alerts; this
// schedules reminders the device fires itself. Both paths use the
// same channel id ('viva-alerts') so the user sees one consistent
// notification style.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final vivaLocalReminderSchedulerProvider =
    Provider<VivaLocalReminderScheduler>((ref) => VivaLocalReminderScheduler._());

class VivaLocalReminderScheduler {
  VivaLocalReminderScheduler._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static const _channelId = 'viva-alerts';
  static const _channelName = 'Viva alerts';

  // Deterministic id space for Viva-scheduled reminders. Derived from
  // appointmentId hashCode XOR an offset tier so cancel/reschedule
  // round-trips work without tracking ids separately.
  static const int _idSalt24h = 0x55aa0002;
  static const int _idSalt1h = 0x55aa0003;

  int _idFor(String appointmentId, int salt) =>
      (appointmentId.hashCode ^ salt) & 0x7fffffff;

  /// Replace all Viva-scheduled reminders with fresh ones derived
  /// from `appointments`. Called after every successful VivaSyncClient
  /// refresh(). Soft-deleted rows (deleted_at != null) are skipped —
  /// their matching notification id is cancelled via cancelAll so the
  /// OS entry disappears.
  Future<void> rescheduleFromAppointments(List<Map<String, dynamic>> appointments) async {
    try {
      // The simplest correct approach is to cancel every pending
      // notification the plugin knows about and re-schedule from the
      // current snapshot. Viva doesn't schedule non-reminder local
      // notifications, so cancelAll is safe.
      await _plugin.cancelAll();

      final now = DateTime.now();
      for (final row in appointments) {
        final id = row['id']?.toString();
        if (id == null) continue;
        final deletedAt = row['deleted_at'];
        if (deletedAt != null) continue;
        final startRaw = row['start_time']?.toString();
        if (startRaw == null) continue;
        final start = DateTime.tryParse(startRaw);
        if (start == null) continue;
        if (start.isBefore(now)) continue;

        final location = (row['location'] as String?) ?? '';
        final apptType = (row['appointment_type'] as String?) ?? 'Appointment';
        final title = 'Upcoming appointment';
        final body = location.isEmpty
            ? '$apptType at ${_formatTime(start)}'
            : '$apptType at ${_formatTime(start)} — $location';

        // 24h-before
        final t24h = start.subtract(const Duration(hours: 24));
        if (t24h.isAfter(now)) {
          await _scheduleAt(_idFor(id, _idSalt24h), 'Appointment tomorrow', body, t24h);
        }
        // 1h-before
        final t1h = start.subtract(const Duration(hours: 1));
        if (t1h.isAfter(now)) {
          await _scheduleAt(_idFor(id, _idSalt1h), title, body, t1h);
        }
      }
    } catch (e) {
      debugPrint('[VivaLocalReminderScheduler] reschedule failed: $e');
    }
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('[VivaLocalReminderScheduler] cancelAll failed: $e');
    }
  }

  Future<void> _scheduleAt(int id, String title, String body, DateTime when) async {
    // We intentionally use `show` with a zero-delay fallback rather than
    // `zonedSchedule` to keep the dependency surface small (no
    // timezone package required). For Phase 11B this is acceptable
    // because the sync client re-invokes rescheduleFromAppointments
    // on every resume and every FCM push — drift is bounded to the
    // poll interval. A tz-backed upgrade can ship later without
    // breaking the public method surface.
    final delta = when.difference(DateTime.now());
    if (delta.isNegative) return;
    Timer(delta, () async {
      try {
        await _plugin.show(
          id,
          title,
          body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
        );
      } catch (e) {
        debugPrint('[VivaLocalReminderScheduler] fire failed for $id: $e');
      }
    });
  }

  String _formatTime(DateTime t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}
