import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Local tracking data — stored on device, synced to API when possible.
/// Tracks: mood, energy, sleep, pain, medication adherence, vitals.

class TrackingEntry {
  final String type; // mood, energy, sleep, pain, meds, weight, bloodSugar, bloodPressure
  final double value;
  final String? note;
  final DateTime timestamp;

  TrackingEntry({required this.type, required this.value, this.note, DateTime? timestamp})
      : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'type': type, 'value': value, 'note': note, 'timestamp': timestamp.toIso8601String(),
  };

  factory TrackingEntry.fromJson(Map<String, dynamic> j) => TrackingEntry(
    type: j['type'] as String,
    value: (j['value'] as num).toDouble(),
    note: j['note'] as String?,
    timestamp: DateTime.parse(j['timestamp'] as String),
  );
}

class TrackingService {
  static const _storageKey = 'viva_tracking';

  Future<List<TrackingEntry>> getEntries(String type, {int days = 30}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey) ?? '[]';
    final list = (jsonDecode(raw) as List).map((j) => TrackingEntry.fromJson(j as Map<String, dynamic>)).toList();
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return list.where((e) => e.type == type && e.timestamp.isAfter(cutoff)).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  Future<List<TrackingEntry>> getAllEntries({int days = 7}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey) ?? '[]';
    final list = (jsonDecode(raw) as List).map((j) => TrackingEntry.fromJson(j as Map<String, dynamic>)).toList();
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return list.where((e) => e.timestamp.isAfter(cutoff)).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Future<void> addEntry(TrackingEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey) ?? '[]';
    final list = jsonDecode(raw) as List;
    list.add(entry.toJson());
    // Keep last 1000 entries
    if (list.length > 1000) list.removeRange(0, list.length - 1000);
    await prefs.setString(_storageKey, jsonEncode(list));
  }

  /// Delete an entry by matching type, value, and approximate timestamp
  Future<void> deleteEntry(String type, double value, DateTime timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey) ?? '[]';
    final list = (jsonDecode(raw) as List).toList();
    list.removeWhere((e) {
      final entry = e as Map<String, dynamic>;
      return entry['type'] == type
          && (entry['value'] as num).toDouble() == value
          && DateTime.parse(entry['timestamp'] as String).difference(timestamp).inSeconds.abs() < 5;
    });
    await prefs.setString(_storageKey, jsonEncode(list));
  }

  Future<TrackingEntry?> getLatest(String type) async {
    final entries = await getEntries(type, days: 7);
    return entries.isNotEmpty ? entries.last : null;
  }

  Future<double?> getTodayValue(String type) async {
    final entries = await getEntries(type, days: 1);
    final today = DateTime.now();
    final todayEntries = entries.where((e) =>
        e.timestamp.year == today.year && e.timestamp.month == today.month && e.timestamp.day == today.day);
    return todayEntries.isNotEmpty ? todayEntries.last.value : null;
  }
}

final trackingServiceProvider = Provider<TrackingService>((_) => TrackingService());
