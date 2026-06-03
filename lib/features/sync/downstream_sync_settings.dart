// apps/patient-app/lib/features/sync/downstream_sync_settings.dart
//
// Phase 11E — patient-controlled downstream sync preferences.
//
// The existing sync_settings_screen.dart controls UPSTREAM sync
// (the patient's tracking data, vitals, diary, goals — pushed to
// the clinic). This widget controls DOWNSTREAM sync (appointments,
// messages, documents, notifications, reminders — pulled from the
// clinic to the device). Two different taxonomies, one screen.
//
// Each toggle hits PATCH /patient-app/sync-preferences which
// upserts the patient_sync_preferences row and sets
// updated_by_patient = true for the audit trail. On first read
// the API lazily materialises five rows (one per module) as
// enabled=false so the UI always renders a complete list.
//
// This widget is self-contained — it owns its own fetch / mutation
// logic and doesn't depend on the existing _SyncSettingsState. The
// existing screen appends it at the bottom as an additional
// section without touching its own state.
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/api/api_client.dart';

class DownstreamSyncSettings extends StatefulWidget {
  const DownstreamSyncSettings({super.key});

  @override
  State<DownstreamSyncSettings> createState() => _DownstreamSyncSettingsState();
}

class _DownstreamSyncSettingsState extends State<DownstreamSyncSettings> {
  bool _loading = true;
  bool _saving = false;
  List<_ModulePreference> _items = [];

  static const _moduleMeta = <String, _ModuleMeta>{
    'appointments': _ModuleMeta('Appointments', 'Upcoming visits + reminders', Icons.event, Color(0xFF2196F3)),
    'messages': _ModuleMeta('Messages', 'Clinical messages from your care team', Icons.chat_bubble_outline, Color(0xFF5C6BC0)),
    'documents': _ModuleMeta('Documents', 'Care plan, discharge summaries, letters', Icons.folder_outlined, kMeds),
    'notifications': _ModuleMeta('Notifications', 'General alerts from the clinic', Icons.notifications_outlined, kWarning),
    'reminders': _ModuleMeta('Reminders', 'Medication + activity reminders', Icons.schedule, kSuccess),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final resp = await pApi.get('/patient-app/sync-preferences');
      final items = (resp['items'] as List).map((e) {
        final map = e as Map<String, dynamic>;
        return _ModulePreference(
          moduleKey: map['moduleKey'] as String,
          enabled: map['enabled'] as bool,
          updatedByPatient: map['updatedByPatient'] as bool? ?? false,
        );
      }).toList();
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[DownstreamSyncSettings] load failed: $e');
      setState(() {
        _items = _moduleMeta.keys
            .map((k) => _ModulePreference(moduleKey: k, enabled: false, updatedByPatient: false))
            .toList();
        _loading = false;
      });
    }
  }

  Future<void> _toggle(String moduleKey, bool enabled) async {
    setState(() {
      _saving = true;
      _items = _items.map((i) =>
        i.moduleKey == moduleKey
          ? _ModulePreference(moduleKey: moduleKey, enabled: enabled, updatedByPatient: true)
          : i
      ).toList();
    });
    try {
      await pApi.patch('/patient-app/sync-preferences', data: {
        'moduleKey': moduleKey,
        'enabled': enabled,
      });
    } catch (e) {
      // Revert on failure so the UI matches the server.
      setState(() {
        _items = _items.map((i) =>
          i.moduleKey == moduleKey
            ? _ModulePreference(moduleKey: moduleKey, enabled: !enabled, updatedByPatient: i.updatedByPatient)
            : i
        ).toList();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update sync preference: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            'What the clinic sends you',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kText),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            'Choose which updates sync to this device. Turning a section off removes it from this device on the next sync — the clinic still has a copy.',
            style: TextStyle(fontSize: 12, color: kTextLight),
          ),
        ),
        ..._items.map(_buildRow),
        if (_saving)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Center(child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))),
          ),
      ],
    );
  }

  Widget _buildRow(_ModulePreference pref) {
    final meta = _moduleMeta[pref.moduleKey] ?? _moduleMeta['notifications']!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: meta.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(meta.icon, size: 18, color: meta.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(meta.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(meta.description, style: const TextStyle(fontSize: 11, color: kTextLight)),
              ],
            ),
          ),
          Switch(
            value: pref.enabled,
            onChanged: _saving ? null : (v) => _toggle(pref.moduleKey, v),
          ),
        ],
      ),
    );
  }
}

class _ModulePreference {
  const _ModulePreference({
    required this.moduleKey,
    required this.enabled,
    required this.updatedByPatient,
  });
  final String moduleKey;
  final bool enabled;
  final bool updatedByPatient;
}

class _ModuleMeta {
  const _ModuleMeta(this.title, this.description, this.icon, this.color);
  final String title;
  final String description;
  final IconData icon;
  final Color color;
}
