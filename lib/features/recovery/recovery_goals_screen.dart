import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../core/theme.dart';

/// Recovery goals — track personal recovery milestones.
class RecoveryGoalsScreen extends StatefulWidget {
  const RecoveryGoalsScreen({super.key});
  @override
  State<RecoveryGoalsScreen> createState() => _RecoveryGoalsState();
}

class _RecoveryGoalsState extends State<RecoveryGoalsScreen> {
  List<Map<String, dynamic>> _goals = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('viva_goals') ?? '[]';
    setState(() { _goals = (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(); _loading = false; });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('viva_goals', jsonEncode(_goals));
  }

  void _addGoal() {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _GoalSheet(onSaved: (goal) { setState(() => _goals.add(goal)); _save(); }),
    );
  }

  void _editGoal(int index) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _GoalSheet(existing: _goals[index], onSaved: (goal) { setState(() => _goals[index] = goal); _save(); }),
    );
  }

  void _toggleStep(int goalIdx, int stepIdx) {
    final steps = List<Map<String, dynamic>>.from(_goals[goalIdx]['steps'] as List? ?? []);
    steps[stepIdx]['done'] = !(steps[stepIdx]['done'] as bool? ?? false);
    _goals[goalIdx]['steps'] = steps;
    // Update progress
    final total = steps.length;
    final done = steps.where((s) => s['done'] == true).length;
    _goals[goalIdx]['progress'] = total > 0 ? (done / total * 100).round() : 0;
    setState(() {});
    _save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(title: const Text('Recovery Goals')),
      floatingActionButton: FloatingActionButton(
        onPressed: _addGoal,
        backgroundColor: kPrimary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: kPrimary))
        : _goals.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.flag_outlined, size: 48, color: kTextLight.withAlpha(100)),
              const SizedBox(height: 12),
              const Text('No goals yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: kText)),
              Text('Set recovery goals to track your progress', style: TextStyle(fontSize: 12, color: kTextLight)),
            ]))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 80),
              itemCount: _goals.length,
              itemBuilder: (_, i) => _GoalCard(
                goal: _goals[i], onTap: () => _editGoal(i),
                onToggleStep: (si) => _toggleStep(i, si),
              ),
            ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final Map<String, dynamic> goal;
  final VoidCallback onTap;
  final void Function(int stepIndex) onToggleStep;
  const _GoalCard({required this.goal, required this.onTap, required this.onToggleStep});

  @override
  Widget build(BuildContext context) {
    final title = goal['title'] ?? 'Goal';
    final category = goal['category'] ?? '';
    final progress = (goal['progress'] as int? ?? 0).clamp(0, 100);
    final steps = (goal['steps'] as List?)?.map((s) => Map<String, dynamic>.from(s as Map)).toList() ?? [];
    final targetDate = goal['targetDate'] as String?;
    final color = progress >= 100 ? kSuccess : progress > 50 ? kWarning : kPrimary;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: kDivider)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InkWell(
            onTap: onTap,
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(10)),
                child: Icon(progress >= 100 ? Icons.check_circle : Icons.flag, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title.toString(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kText)),
                if (category.toString().isNotEmpty) Text(category.toString(), style: TextStyle(fontSize: 11, color: kTextLight)),
              ])),
              Text('$progress%', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
            ]),
          ),
          // Progress bar
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: progress / 100, backgroundColor: kDivider, color: color, minHeight: 6),
            ),
          ),
          if (targetDate != null) Text('Target: $targetDate', style: TextStyle(fontSize: 10, color: kTextLight)),
          // Steps
          if (steps.isNotEmpty) ...[
            const Divider(height: 16),
            ...steps.asMap().entries.map((e) {
              final step = e.value;
              final done = step['done'] == true;
              return InkWell(
                onTap: () => onToggleStep(e.key),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 18, color: done ? kSuccess : kTextLight),
                    const SizedBox(width: 8),
                    Expanded(child: Text(step['text'] ?? '', style: TextStyle(
                      fontSize: 12, color: done ? kTextLight : kText,
                      decoration: done ? TextDecoration.lineThrough : null,
                    ))),
                  ]),
                ),
              );
            }),
          ],
        ]),
      ),
    );
  }
}

class _GoalSheet extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final void Function(Map<String, dynamic>) onSaved;
  const _GoalSheet({this.existing, required this.onSaved});

  @override
  State<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<_GoalSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _dateCtrl;
  String _category = 'Personal';
  final List<TextEditingController> _stepCtrls = [];

  static const _categories = ['Personal', 'Exercise/Walking', 'Social', 'Health', 'Employment', 'Education', 'Housing', 'Relationships', 'Others'];

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.existing?['title'] ?? '');
    _dateCtrl = TextEditingController(text: widget.existing?['targetDate'] ?? '');
    _category = widget.existing?['category'] ?? 'Personal';
    final steps = (widget.existing?['steps'] as List?)?.map((s) => Map<String, dynamic>.from(s as Map)).toList() ?? [];
    for (final s in steps) { _stepCtrls.add(TextEditingController(text: s['text'] ?? '')); }
    if (_stepCtrls.isEmpty) _stepCtrls.add(TextEditingController());
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _dateCtrl.dispose();
    for (final c in _stepCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(widget.existing != null ? 'Edit Goal' : 'New Goal',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: kText)),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
          ]),
          const Divider(),
          TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Goal *')),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 4, children: _categories.map((c) => ChoiceChip(
            label: Text(c, style: const TextStyle(fontSize: 11)),
            selected: _category == c, selectedColor: kPrimary.withAlpha(25),
            onSelected: (_) => setState(() => _category = c),
          )).toList()),
          const SizedBox(height: 10),
          TextField(controller: _dateCtrl, decoration: const InputDecoration(labelText: 'Target Date (optional)', hintText: 'DD/MM/YYYY')),
          const SizedBox(height: 14),
          const Text('Steps', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextLight)),
          ..._stepCtrls.asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(children: [
              Expanded(child: TextField(controller: e.value, decoration: InputDecoration(labelText: 'Step ${e.key + 1}', isDense: true))),
              if (_stepCtrls.length > 1) IconButton(icon: const Icon(Icons.remove_circle_outline, size: 18, color: kError),
                onPressed: () => setState(() { _stepCtrls[e.key].dispose(); _stepCtrls.removeAt(e.key); })),
            ]),
          )),
          TextButton.icon(icon: const Icon(Icons.add, size: 16), label: const Text('Add Step', style: TextStyle(fontSize: 12)),
            onPressed: () => setState(() => _stepCtrls.add(TextEditingController()))),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: () {
            if (_titleCtrl.text.trim().isEmpty) return;
            final existingSteps = (widget.existing?['steps'] as List?)?.map((s) => Map<String, dynamic>.from(s as Map)).toList() ?? [];
            final steps = _stepCtrls.where((c) => c.text.trim().isNotEmpty).toList().asMap().entries.map((e) => {
              'text': e.value.text.trim(),
              'done': e.key < existingSteps.length ? (existingSteps[e.key]['done'] ?? false) : false,
            }).toList();
            final done = steps.where((s) => s['done'] == true).length;
            widget.onSaved({
              'title': _titleCtrl.text.trim(), 'category': _category,
              'targetDate': _dateCtrl.text.trim().isNotEmpty ? _dateCtrl.text.trim() : null,
              'steps': steps, 'progress': steps.isNotEmpty ? (done / steps.length * 100).round() : 0,
              'createdAt': widget.existing?['createdAt'] ?? DateTime.now().toIso8601String(),
            });
            Navigator.pop(context);
          }, child: const Text('Save Goal')),
        ]),
      ),
    );
  }
}
