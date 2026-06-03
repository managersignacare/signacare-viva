import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/api/api_client.dart';

/// My Tasks — tasks assigned by clinician, patient can mark complete.
class PatientTasksScreen extends StatefulWidget {
  const PatientTasksScreen({super.key});
  @override
  State<PatientTasksScreen> createState() => _PatientTasksState();
}

class _PatientTasksState extends State<PatientTasksScreen> {
  List<Map<String, dynamic>> _tasks = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final pid = await pApi.patientId;
      if (pid != null) {
        final data = await pApi.get('/patient-app/tasks/$pid');
        _tasks = ((data as Map)['tasks'] as List? ?? []).map((j) => Map<String, dynamic>.from(j as Map)).toList();
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _showAddTask(BuildContext context) {
    final titleCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    String dueDate = '';

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, setSheetState) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Add Task', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: kText)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ]),
            const Divider(),
            TextField(controller: titleCtrl, autofocus: true,
              decoration: const InputDecoration(labelText: 'What do you need to do? *', hintText: 'e.g. Pick up prescription',
                prefixIcon: Icon(Icons.task_alt, size: 20))),
            const SizedBox(height: 10),
            // Due date
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(context: ctx,
                  initialDate: DateTime.now().add(const Duration(days: 1)),
                  firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                if (picked != null) setSheetState(() => dueDate = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Due date (optional)', prefixIcon: Icon(Icons.calendar_today, size: 20)),
                child: Text(dueDate.isNotEmpty ? dueDate : 'Tap to set', style: TextStyle(fontSize: 14, color: dueDate.isNotEmpty ? kText : kTextLight)),
              ),
            ),
            const SizedBox(height: 10),
            // Location
            TextField(controller: locationCtrl,
              decoration: const InputDecoration(labelText: 'Location (optional)',
                hintText: 'e.g. Supermarket, Pharmacy, Centrelink',
                prefixIcon: Icon(Icons.location_on_outlined, size: 20))),
            const SizedBox(height: 6),
            Text('Location-based reminders available on native iOS/Android',
              style: TextStyle(fontSize: 10, color: kTextLight)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: () async {
              if (titleCtrl.text.trim().isEmpty) return;
              try {
                final pid = await pApi.patientId;
                await pApi.post('/patient-app/tasks/$pid', data: {
                  'title': titleCtrl.text.trim(),
                  if (dueDate.isNotEmpty) 'dueDate': dueDate,
                  if (locationCtrl.text.trim().isNotEmpty) 'location': locationCtrl.text.trim(),
                });
                if (context.mounted) Navigator.pop(context);
                _load();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Task added'), backgroundColor: kSuccess),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e'), backgroundColor: kError),
                  );
                }
              }
            }, child: const Text('Add Task')),
          ]),
        ),
      )),
    );
  }

  Future<void> _complete(String taskId) async {
    try {
      final pid = await pApi.patientId;
      await pApi.patch('/patient-app/tasks/$pid/$taskId', data: {'status': 'completed'});
      _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task completed!'), backgroundColor: kSuccess));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final pending = _tasks.where((t) => t['status'] == 'pending').toList();
    final completed = _tasks.where((t) => t['status'] == 'completed').toList();

    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(title: const Text('My Tasks')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: kPrimary, child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _showAddTask(context),
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: kPrimary))
        : _tasks.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.task_alt, size: 48, color: kSuccess.withAlpha(100)),
              const SizedBox(height: 12),
              const Text('No tasks', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: kText)),
              Text('Tasks from your care team will appear here', style: TextStyle(fontSize: 12, color: kTextLight)),
            ]))
          : RefreshIndicator(
              color: kPrimary,
              onRefresh: () async { setState(() => _loading = true); _load(); },
              child: ListView(padding: const EdgeInsets.all(14), children: [
                if (pending.isNotEmpty) ...[
                  Text('To Do (${pending.length})', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kPrimary)),
                  const SizedBox(height: 8),
                  ...pending.map((t) => _TaskCard(task: t, onComplete: () => _complete(t['id']?.toString() ?? ''))),
                  const SizedBox(height: 16),
                ],
                if (completed.isNotEmpty) ...[
                  Text('Done (${completed.length})', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kSuccess)),
                  const SizedBox(height: 8),
                  ...completed.map((t) => _TaskCard(task: t, onComplete: null)),
                ],
              ]),
            ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final Map<String, dynamic> task;
  final VoidCallback? onComplete;
  const _TaskCard({required this.task, this.onComplete});

  @override
  Widget build(BuildContext context) {
    final isDone = task['status'] == 'completed';
    final dueDate = task['dueDate'] ?? task['due_date'];
    final dt = dueDate != null ? DateTime.tryParse(dueDate.toString()) : null;
    final dueStr = dt != null ? '${dt.day}/${dt.month}/${dt.year}' : '';
    final isOverdue = dt != null && dt.isBefore(DateTime.now()) && !isDone;
    final location = task['location'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDone ? kSuccess.withAlpha(40) : isOverdue ? kError.withAlpha(60) : kDivider)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isDone ? null : onComplete,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Icon(isDone ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isDone ? kSuccess : isOverdue ? kError : kPrimary, size: 24),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(task['title'] ?? 'Task', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: isDone ? kTextLight : kText, decoration: isDone ? TextDecoration.lineThrough : null)),
              if (task['description'] != null && (task['description'] as String).isNotEmpty)
                Text(task['description'], style: TextStyle(fontSize: 11, color: kTextLight), maxLines: 2, overflow: TextOverflow.ellipsis),
              if (dueStr.isNotEmpty)
                Text('Due: $dueStr', style: TextStyle(fontSize: 10, color: isOverdue ? kError : kTextLight, fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal)),
              if (location != null && location.isNotEmpty)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.location_on, size: 10, color: kTextLight),
                  const SizedBox(width: 2),
                  Text(location, style: TextStyle(fontSize: 10, color: kTextLight)),
                ]),
            ])),
            if (!isDone) const Icon(Icons.chevron_right, size: 18, color: kTextLight),
          ]),
        ),
      ),
    );
  }
}
