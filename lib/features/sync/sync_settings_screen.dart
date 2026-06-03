import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../core/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/services/tracking_service.dart';
import 'downstream_sync_settings.dart';

/// Sync settings — patient controls which data sections sync to the desktop EMR.
class SyncSettingsScreen extends StatefulWidget {
  const SyncSettingsScreen({super.key});
  @override
  State<SyncSettingsScreen> createState() => _SyncSettingsState();
}

class _SyncSettingsState extends State<SyncSettingsScreen> {
  Map<String, bool> _syncEnabled = {};
  bool _loading = true;
  bool _syncing = false;
  String? _lastSync;

  static const _sections = [
    _SyncSection('tracking', 'Mood & Wellbeing', 'Mood, anxiety, sleep, energy scores', Icons.track_changes, Color(0xFF2196F3)),
    _SyncSection('vitals', 'Vitals', 'Weight, BMI, blood pressure, blood sugar', Icons.monitor_heart, kError),
    _SyncSection('meds_adherence', 'Medication Adherence', 'Taken/missed responses', Icons.medication, kMeds),
    _SyncSection('diary', 'Diary Entries', 'Personal journal (shared with care team)', Icons.book, Color(0xFF5C6BC0)),
    _SyncSection('goals', 'Recovery Goals', 'Goals and progress', Icons.flag, kSuccess),
    _SyncSection('activities', 'Activity Schedule', 'Daily activities and completion', Icons.schedule, kWarning),
    _SyncSection('profile', 'Profile & Allergies', 'Contact details, allergies, consent', Icons.person, kPrimary),
  ];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('viva_sync_settings') ?? '{}';
    final data = jsonDecode(raw) as Map<String, dynamic>;
    _syncEnabled = { for (final s in _sections) s.key: data[s.key] == true };
    _lastSync = prefs.getString('viva_last_sync');
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('viva_sync_settings', jsonEncode(_syncEnabled));
  }

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    int synced = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      final ts = TrackingService();

      // Sync each enabled section
      if (_syncEnabled['tracking'] == true) {
        final entries = await ts.getAllEntries(days: 30);
        final trackingData = entries.where((e) => ['mood', 'anxiety', 'sleep', 'energy'].contains(e.type)).toList();
        if (trackingData.isNotEmpty) {
          await pApi.post('/patient-app/tracking', data: {
            'entries': trackingData.map((e) => {'type': e.type, 'value': e.value, 'note': e.note, 'timestamp': e.timestamp.toIso8601String()}).toList(),
          });
          synced += trackingData.length;
        }
      }

      if (_syncEnabled['vitals'] == true) {
        final types = ['weight', 'height', 'bpSystolic', 'bpDiastolic', 'bloodSugar'];
        for (final t in types) {
          final entries = await ts.getEntries(t, days: 90);
          if (entries.isNotEmpty) {
            await pApi.post('/patient-app/tracking', data: {
              'entries': entries.map((e) => {'type': e.type, 'value': e.value, 'note': e.note, 'timestamp': e.timestamp.toIso8601String()}).toList(),
            });
            synced += entries.length;
          }
        }
      }

      if (_syncEnabled['meds_adherence'] == true) {
        final entries = await ts.getEntries('meds', days: 30);
        if (entries.isNotEmpty) {
          await pApi.post('/patient-app/tracking', data: {
            'entries': entries.map((e) => {'type': 'meds', 'value': e.value, 'note': e.note, 'timestamp': e.timestamp.toIso8601String()}).toList(),
          });
          synced += entries.length;
        }
      }

      if (_syncEnabled['diary'] == true) {
        final raw = prefs.getString('viva_diary') ?? '[]';
        final diaryEntries = jsonDecode(raw) as List;
        if (diaryEntries.isNotEmpty) {
          await pApi.post('/patient-app/tracking', data: {
            'entries': diaryEntries.map((e) => {'type': 'diary', 'value': 0, 'note': jsonEncode(e), 'timestamp': e['date']}).toList(),
          });
          synced += diaryEntries.length;
        }
      }

      if (_syncEnabled['goals'] == true) {
        final raw = prefs.getString('viva_goals') ?? '[]';
        final goals = jsonDecode(raw) as List;
        if (goals.isNotEmpty) {
          await pApi.post('/patient-app/tracking', data: {
            'entries': goals.map((g) => {'type': 'goal', 'value': (g['progress'] ?? 0).toDouble(), 'note': jsonEncode(g)}).toList(),
          });
          synced += goals.length;
        }
      }

      if (_syncEnabled['activities'] == true) {
        final raw = prefs.getString('viva_activities') ?? '[]';
        final acts = jsonDecode(raw) as List;
        if (acts.isNotEmpty) {
          await pApi.post('/patient-app/tracking', data: {
            'entries': acts.map((a) => {'type': 'activity', 'value': a['done'] == true ? 1.0 : 0.0, 'note': jsonEncode(a)}).toList(),
          });
          synced += acts.length;
        }
      }

      if (_syncEnabled['profile'] == true) {
        final raw = prefs.getString('viva_profile') ?? '{}';
        await pApi.post('/patient-app/tracking', data: {
          'entries': [{'type': 'profile', 'value': 0, 'note': raw}],
        });
        synced += 1;
      }

      final now = DateTime.now().toIso8601String();
      await prefs.setString('viva_last_sync', now);
      setState(() { _lastSync = now; _syncing = false; });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Synced $synced entries to your care team'), backgroundColor: kSuccess),
        );
      }
    } catch (e) {
      setState(() => _syncing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e'), backgroundColor: kError),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: kPrimary)));

    final enabledCount = _syncEnabled.values.where((v) => v).length;

    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(title: const Text('Sync Settings')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // Status card
          Card(
            color: kPrimary.withAlpha(10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: kPrimary.withAlpha(30))),
            child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.sync, color: kPrimary, size: 22),
                const SizedBox(width: 10),
                const Text('Data Sync', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kText)),
              ]),
              const SizedBox(height: 8),
              Text('$enabledCount of ${_sections.length} sections enabled for sync', style: TextStyle(fontSize: 12, color: kTextLight)),
              if (_lastSync != null) Text('Last sync: ${_formatDate(_lastSync!)}', style: TextStyle(fontSize: 11, color: kTextLight)),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: ElevatedButton.icon(
                onPressed: _syncing || enabledCount == 0 ? null : _syncNow,
                icon: _syncing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.cloud_upload, color: Colors.white, size: 18),
                label: Text(_syncing ? 'Syncing...' : 'Sync Now'),
              )),
            ])),
          ),
          const SizedBox(height: 14),

          // Info
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: kInfo.withAlpha(10), borderRadius: BorderRadius.circular(8)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline, size: 14, color: kInfo),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'Choose which sections of your wellbeing data to share with your care team. '
                'Only enabled sections will be visible in the desktop EMR.',
                style: TextStyle(fontSize: 11, color: kTextLight, height: 1.4))),
            ]),
          ),
          const SizedBox(height: 14),

          // Section toggles
          ..._sections.map((s) {
            final enabled = _syncEnabled[s.key] == true;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: enabled ? s.color.withAlpha(60) : kDivider)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(children: [
                  Container(width: 34, height: 34, decoration: BoxDecoration(color: s.color.withAlpha(20), borderRadius: BorderRadius.circular(8)),
                    child: Icon(s.icon, color: s.color, size: 18)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: enabled ? s.color : kText)),
                    Text(s.subtitle, style: TextStyle(fontSize: 10, color: kTextLight)),
                  ])),
                  Switch.adaptive(
                    value: enabled,
                    activeThumbColor: s.color,
                    activeTrackColor: s.color.withAlpha(80),
                    onChanged: (v) { setState(() => _syncEnabled[s.key] = v); _save(); }),
                ]),
              ),
            );
          }),
          // Phase 11E — patient-controlled downstream sync. The
          // self-contained widget owns its own load / mutate /
          // optimistic-update logic and writes to the new
          // /patient-app/sync-preferences endpoint. Separate from
          // the upstream toggles above (which push tracking data
          // to the clinic) — this controls what the clinic sends
          // to the device.
          const Divider(height: 32),
          const DownstreamSyncSettings(),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _SyncSection {
  final String key, label, subtitle;
  final IconData icon;
  final Color color;
  const _SyncSection(this.key, this.label, this.subtitle, this.icon, this.color);
}
