import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../core/theme.dart';

/// Activity scheduling — BACE-style behavioural activation with templates.
class ActivityScheduleScreen extends StatefulWidget {
  const ActivityScheduleScreen({super.key});
  @override
  State<ActivityScheduleScreen> createState() => _ActivityScheduleState();
}

class _ActivityScheduleState extends State<ActivityScheduleScreen> {
  List<Map<String, dynamic>> _activities = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('viva_activities') ?? '[]';
    setState(() { _activities = (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList()
      ..sort((a, b) => (a['time'] as String? ?? '').compareTo(b['time'] as String? ?? '')); _loading = false; });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('viva_activities', jsonEncode(_activities));
  }

  void _addActivity({Map<String, dynamic>? template}) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _ActivitySheet(template: template, onSaved: (a) { setState(() => _activities.add(a)); _save(); }),
    );
  }

  void _toggleDone(int index) {
    _activities[index]['done'] = !(_activities[index]['done'] as bool? ?? false);
    _activities[index]['completedAt'] = _activities[index]['done'] == true ? DateTime.now().toIso8601String() : null;
    setState(() {});
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('EEEE, d MMMM').format(DateTime.now());

    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(title: const Text('Activity Schedule')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: kPrimary, child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _addActivity(),
      ),
      body: Column(children: [
        // Templates bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          color: Colors.white,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(today, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kText)),
            const SizedBox(height: 8),
            const Text('Templates', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kTextLight)),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    avatar: const Icon(Icons.add_circle_outline, size: 14, color: kPrimary),
                    label: const Text('Custom Activity', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                    backgroundColor: kPrimary.withAlpha(15),
                    side: BorderSide(color: kPrimary.withAlpha(40)),
                    onPressed: () => _addActivity(),
                  ),
                ),
                ..._templates.map((t) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    avatar: Icon(t['icon'] as IconData, size: 14, color: t['color'] as Color),
                    label: Text(t['name'] as String, style: const TextStyle(fontSize: 10)),
                    backgroundColor: (t['color'] as Color).withAlpha(15),
                    side: BorderSide(color: (t['color'] as Color).withAlpha(40)),
                    onPressed: () => _addActivity(template: t),
                  ),
                )),
              ]),
            ),
          ]),
        ),
        const Divider(height: 1),

        // Activities list
        Expanded(
          child: _loading
            ? const Center(child: CircularProgressIndicator(color: kPrimary))
            : _activities.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.schedule_outlined, size: 48, color: kTextLight.withAlpha(100)),
                  const SizedBox(height: 12),
                  const Text('No activities planned', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: kText)),
                  Text('Use templates above or tap + to add', style: TextStyle(fontSize: 12, color: kTextLight)),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 80),
                  itemCount: _activities.length,
                  itemBuilder: (_, i) => _ActivityCard(
                    activity: _activities[i],
                    onToggle: () => _toggleDone(i),
                  ),
                ),
        ),
      ]),
    );
  }

  static final List<Map<String, dynamic>> _templates = [
    {'name': 'BACE Morning', 'icon': Icons.wb_sunny, 'color': kMood, 'activities': [
      {'time': '07:00', 'name': 'Wake up & stretch', 'category': 'Self-care'},
      {'time': '07:30', 'name': 'Breakfast', 'category': 'Self-care'},
      {'time': '08:00', 'name': 'Walk outside (15 min)', 'category': 'Exercise'},
      {'time': '08:30', 'name': 'Mindfulness (5 min)', 'category': 'Wellbeing'},
    ]},
    {'name': 'BACE Afternoon', 'icon': Icons.wb_cloudy, 'color': kEnergy, 'activities': [
      {'time': '12:00', 'name': 'Lunch', 'category': 'Self-care'},
      {'time': '13:00', 'name': 'Creative activity', 'category': 'Pleasure'},
      {'time': '14:00', 'name': 'Social contact', 'category': 'Social'},
      {'time': '15:00', 'name': 'Light exercise', 'category': 'Exercise'},
    ]},
    {'name': 'BACE Evening', 'icon': Icons.nightlight, 'color': kSleep, 'activities': [
      {'time': '18:00', 'name': 'Dinner', 'category': 'Self-care'},
      {'time': '19:00', 'name': 'Relaxation activity', 'category': 'Pleasure'},
      {'time': '20:00', 'name': 'Wind-down routine', 'category': 'Wellbeing'},
      {'time': '21:00', 'name': 'Sleep hygiene', 'category': 'Self-care'},
    ]},
    {'name': 'Exercise', 'icon': Icons.fitness_center, 'color': kSuccess, 'activities': [
      {'time': '09:00', 'name': 'Warm up (5 min)', 'category': 'Exercise'},
      {'time': '09:10', 'name': 'Main exercise (20 min)', 'category': 'Exercise'},
      {'time': '09:35', 'name': 'Cool down & stretch', 'category': 'Exercise'},
    ]},
    {'name': 'Social', 'icon': Icons.people, 'color': kInfo, 'activities': [
      {'time': '10:00', 'name': 'Call a friend/family', 'category': 'Social'},
      {'time': '14:00', 'name': 'Group activity', 'category': 'Social'},
    ]},
  ];
}

class _ActivityCard extends StatelessWidget {
  final Map<String, dynamic> activity;
  final VoidCallback onToggle;
  const _ActivityCard({required this.activity, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final done = activity['done'] == true;
    final time = activity['time'] ?? '';
    final name = activity['name'] ?? 'Activity';
    final category = activity['category'] ?? '';
    final catColor = _categoryColor(category.toString());

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: done ? kSuccess.withAlpha(40) : kDivider)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
              color: done ? kSuccess : kTextLight, size: 22),
            const SizedBox(width: 10),
            if (time.toString().isNotEmpty) ...[
              Text(time.toString(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: done ? kTextLight : kText)),
              const SizedBox(width: 10),
            ],
            Expanded(child: Text(name.toString(), style: TextStyle(
              fontSize: 13, color: done ? kTextLight : kText,
              decoration: done ? TextDecoration.lineThrough : null,
            ))),
            if (category.toString().isNotEmpty) Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: catColor.withAlpha(15), borderRadius: BorderRadius.circular(4)),
              child: Text(category.toString(), style: TextStyle(fontSize: 9, color: catColor, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      ),
    );
  }

  Color _categoryColor(String cat) {
    switch (cat.toLowerCase()) {
      case 'self-care': return kMood;
      case 'exercise': return kSuccess;
      case 'social': return kInfo;
      case 'pleasure': return const Color(0xFF6A1B9A);
      case 'wellbeing': return kSleep;
      default: return kTextLight;
    }
  }
}

class _ActivitySheet extends StatefulWidget {
  final Map<String, dynamic>? template;
  final void Function(Map<String, dynamic>) onSaved;
  const _ActivitySheet({this.template, required this.onSaved});

  @override
  State<_ActivitySheet> createState() => _ActivitySheetState();
}

class _ActivitySheetState extends State<_ActivitySheet> {
  final _nameCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  String _category = 'Self-care';

  static const _categories = ['Self-care', 'Exercise', 'Social', 'Pleasure', 'Wellbeing', 'Work', 'Education', 'Chores', 'Other'];

  @override
  void dispose() { _nameCtrl.dispose(); _timeCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    // If template, show template activities to add in bulk
    if (widget.template != null && widget.template!['activities'] != null) {
      final acts = (widget.template!['activities'] as List).map((a) => Map<String, dynamic>.from(a as Map)).toList();
      return Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Add ${widget.template!['name']} Activities', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: kText)),
            const Divider(),
            ...acts.map((a) => ListTile(
              dense: true,
              leading: Text(a['time'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              title: Text(a['name'] ?? '', style: const TextStyle(fontSize: 13)),
              trailing: Chip(label: Text(a['category'] ?? '', style: const TextStyle(fontSize: 9)), padding: EdgeInsets.zero),
            )),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: () {
              for (final a in acts) { widget.onSaved({...a, 'done': false}); }
              Navigator.pop(context);
            }, child: Text('Add All ${acts.length} Activities')),
          ]),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Add Activity', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: kText)),
          const Divider(),
          TextField(controller: _timeCtrl, decoration: const InputDecoration(labelText: 'Time (e.g. 09:00)')),
          const SizedBox(height: 10),
          TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Activity *')),
          const SizedBox(height: 10),
          Wrap(spacing: 6, children: _categories.map((c) => ChoiceChip(
            label: Text(c, style: const TextStyle(fontSize: 11)), selected: _category == c,
            selectedColor: kPrimary.withAlpha(25), onSelected: (_) => setState(() => _category = c),
          )).toList()),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: () {
            if (_nameCtrl.text.trim().isEmpty) return;
            widget.onSaved({'name': _nameCtrl.text.trim(), 'time': _timeCtrl.text.trim(), 'category': _category, 'done': false});
            Navigator.pop(context);
          }, child: const Text('Add')),
        ]),
      ),
    );
  }
}
