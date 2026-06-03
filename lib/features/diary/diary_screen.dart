import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../core/theme.dart';

/// Personal diary — private journal entries stored locally on device.
class DiaryScreen extends ConsumerStatefulWidget {
  const DiaryScreen({super.key});
  @override
  ConsumerState<DiaryScreen> createState() => _DiaryState();
}

class _DiaryState extends ConsumerState<DiaryScreen> {
  List<Map<String, dynamic>> _entries = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('viva_diary') ?? '[]';
    setState(() { _entries = (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList()
      ..sort((a, b) => (b['date'] as String).compareTo(a['date'] as String)); _loading = false; });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('viva_diary', jsonEncode(_entries));
  }

  void _addEntry() {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _DiaryEntrySheet(onSaved: (entry) {
        setState(() => _entries.insert(0, entry));
        _save();
      }),
    );
  }

  void _editEntry(int index) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _DiaryEntrySheet(
        existing: _entries[index],
        onSaved: (entry) { setState(() => _entries[index] = entry); _save(); },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(title: const Text('My Diary')),
      floatingActionButton: FloatingActionButton(
        onPressed: _addEntry,
        backgroundColor: kPrimary,
        child: const Icon(Icons.edit, color: Colors.white),
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: kPrimary))
        : _entries.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.book_outlined, size: 48, color: kTextLight.withAlpha(100)),
              const SizedBox(height: 12),
              const Text('Your diary is empty', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: kText)),
              Text('Tap + to write your first entry', style: TextStyle(fontSize: 12, color: kTextLight)),
              const SizedBox(height: 4),
              Text('Your diary is private and stored only on this device', style: TextStyle(fontSize: 10, color: kTextLight)),
            ]))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 80),
              itemCount: _entries.length,
              itemBuilder: (_, i) => _DiaryCard(entry: _entries[i], onTap: () => _editEntry(i)),
            ),
    );
  }
}

class _DiaryCard extends StatelessWidget {
  final Map<String, dynamic> entry;
  final VoidCallback onTap;
  const _DiaryCard({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.tryParse(entry['date'] ?? '');
    final dateStr = dt != null ? DateFormat('EEEE, d MMM yyyy').format(dt) : '';
    final timeStr = dt != null ? DateFormat('h:mm a').format(dt) : '';
    final mood = entry['mood'] as String? ?? '';
    final content = (entry['content'] ?? '').toString();
    final preview = content.length > 150 ? '${content.substring(0, 150)}...' : content;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: kDivider)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (mood.isNotEmpty) Text(mood, style: const TextStyle(fontSize: 20)),
              if (mood.isNotEmpty) const SizedBox(width: 8),
              Expanded(child: Text(dateStr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kText))),
              Text(timeStr, style: TextStyle(fontSize: 10, color: kTextLight)),
            ]),
            if (entry['title'] != null && (entry['title'] as String).isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 6),
                child: Text(entry['title'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kText))),
            if (preview.isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 4),
                child: Text(preview, style: TextStyle(fontSize: 12, color: kText.withAlpha(180), height: 1.4))),
          ]),
        ),
      ),
    );
  }
}

class _DiaryEntrySheet extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final void Function(Map<String, dynamic> entry) onSaved;
  const _DiaryEntrySheet({this.existing, required this.onSaved});

  @override
  State<_DiaryEntrySheet> createState() => _DiaryEntrySheetState();
}

class _DiaryEntrySheetState extends State<_DiaryEntrySheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  String _mood = '';

  static const _moods = ['😊', '😌', '😐', '😔', '😢', '😤', '😰', '🤗', '💪', '🙏'];

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.existing?['title'] ?? '');
    _contentCtrl = TextEditingController(text: widget.existing?['content'] ?? '');
    _mood = widget.existing?['mood'] ?? '';
  }

  @override
  void dispose() { _titleCtrl.dispose(); _contentCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(widget.existing != null ? 'Edit Entry' : 'New Entry',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: kText)),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
          ]),
          const Divider(),
          const Text('How are you feeling?', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextLight)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, children: _moods.map((m) => GestureDetector(
            onTap: () => setState(() => _mood = _mood == m ? '' : m),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _mood == m ? kPrimary.withAlpha(20) : kSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _mood == m ? kPrimary : Colors.transparent, width: 2),
              ),
              child: Text(m, style: const TextStyle(fontSize: 22)),
            ),
          )).toList()),
          const SizedBox(height: 14),
          TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Title (optional)')),
          const SizedBox(height: 10),
          TextField(controller: _contentCtrl, maxLines: 8,
            decoration: const InputDecoration(labelText: 'Write your thoughts...', alignLabelWithHint: true)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Icon(Icons.mic_outlined, color: kPrimary, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('Voice notes available on iOS/Android — record audio diary entries',
                style: TextStyle(fontSize: 10, color: kTextLight))),
            ]),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              widget.onSaved({
                'date': (widget.existing?['date'] ?? DateTime.now().toIso8601String()),
                'title': _titleCtrl.text.trim(),
                'content': _contentCtrl.text.trim(),
                'mood': _mood,
              });
              Navigator.pop(context);
            },
            child: const Text('Save Entry'),
          ),
          const SizedBox(height: 4),
          Center(child: Text('Private — stored only on your device', style: TextStyle(fontSize: 10, color: kTextLight))),
        ]),
      ),
    );
  }
}
