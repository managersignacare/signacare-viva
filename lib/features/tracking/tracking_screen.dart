import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../core/theme.dart';
import '../../core/services/tracking_service.dart';
import '../../core/api/api_client.dart';

/// Tracker definitions
class _Def {
  final String type, label;
  final Color color;
  final List<String> emojis;
  final String lowLabel, highLabel;
  const _Def(this.type, this.label, this.color, this.emojis, this.lowLabel, this.highLabel);
}

const _trackers = [
  _Def('mood', 'Mood', Color(0xFF2196F3),
    ['😢', '😞', '😕', '😐', '🙂', '😊', '😄', '😁', '🤩', '🥳'], 'Very Low', 'Excellent'),
  _Def('anxiety', 'Anxiety', Color(0xFFE91E63),
    ['😌', '🙂', '😶', '😟', '😰', '😨', '😱', '🫣', '🤯', '💀'], 'Calm', 'Severe'),
  _Def('sleep', 'Sleep', Color(0xFF673AB7),
    ['🥱', '😫', '😩', '😐', '🙂', '😊', '😴', '💤', '🌙', '⭐'], 'Terrible', 'Excellent'),
  _Def('energy', 'Energy', Color(0xFFFF9800),
    ['🪫', '😴', '🥱', '😐', '🙂', '💪', '🔥', '⚡', '🚀', '🌟'], 'Exhausted', 'Full Energy'),
  _Def('pain', 'Pain', Color(0xFFD32F2F),
    ['😊', '🙂', '😐', '😕', '😣', '😖', '😫', '😩', '🤕', '😵'], 'No Pain', 'Severe Pain'),
];

/// Main tracking screen — each tracker gets its own page via PageView
class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key});
  @override
  ConsumerState<TrackingScreen> createState() => _TrackingState();
}

class _TrackingState extends ConsumerState<TrackingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  @override
  void initState() { super.initState(); _tabCtrl = TabController(length: 3, vsync: this); }
  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(title: const Text('Daily Check-in'),
        bottom: TabBar(controller: _tabCtrl, tabs: const [Tab(text: 'Log'), Tab(text: 'Trends'), Tab(text: 'Reminders')])),
      body: TabBarView(controller: _tabCtrl, children: [
        _LogTab(), _TrendsTab(), const _RemindersTab(),
      ]),
    );
  }
}

// ── Log Tab — swipeable pages per tracker ──

class _LogTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_LogTab> createState() => _LogTabState();
}

class _LogTabState extends ConsumerState<_LogTab> {
  final Map<String, double> _values = {};
  final Map<String, String> _notes = {};
  final Map<String, bool> _saved = {};
  bool _loaded = false;
  String? _selectedType; // null = show grid, non-null = show tracker page

  @override
  void initState() { super.initState(); _loadToday(); }

  Future<void> _loadToday() async {
    final ts = ref.read(trackingServiceProvider);
    for (final t in _trackers) {
      final v = await ts.getTodayValue(t.type);
      _values[t.type] = v ?? 5;
      _saved[t.type] = v != null;
    }
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _saveOne(String type) async {
    final ts = ref.read(trackingServiceProvider);
    final value = _values[type] ?? 5;
    final note = _notes[type];
    await ts.addEntry(TrackingEntry(type: type, value: value, note: note?.isNotEmpty == true ? note : null));
    try { await pApi.post('/patient-app/tracking', data: {'entries': [
      {'type': type, 'value': value, 'note': note?.isNotEmpty == true ? note : null}
    ]}); } catch (_) {}
    setState(() { _saved[type] = true; _selectedType = null; }); // back to grid
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_trackers.firstWhere((t) => t.type == type).label} saved'), backgroundColor: kSuccess, duration: const Duration(seconds: 1)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator(color: kPrimary));

    // If a tracker is selected, show its full page
    if (_selectedType != null) {
      final t = _trackers.firstWhere((tr) => tr.type == _selectedType);
      return Column(children: [
        // Back button bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.arrow_back, size: 20), onPressed: () => setState(() => _selectedType = null)),
            Text(t.label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: t.color)),
          ]),
        ),
        Expanded(child: _TrackerPage(
          def: t, value: _values[t.type] ?? 5, saved: _saved[t.type] ?? false,
          onChanged: (v) => setState(() => _values[t.type] = v),
          onNoteChanged: (v) => _notes[t.type] = v,
          onSave: () => _saveOne(t.type),
        )),
      ]);
    }

    // Grid view — pick any tracker
    final dateStr = DateFormat('EEEE, d MMMM').format(DateTime.now());
    final savedCount = _saved.values.where((v) => v).length;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Center(child: Text(dateStr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextLight))),
        const SizedBox(height: 6),
        Center(child: Text('$savedCount of ${_trackers.length} logged today', style: TextStyle(fontSize: 11, color: kTextLight))),
        const SizedBox(height: 14),
        const Text('Tap any measure to record:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kText)),
        const SizedBox(height: 10),
        ..._trackers.map((t) {
          final done = _saved[t.type] == true;
          final val = _values[t.type]?.round() ?? 5;
          final emoji = t.emojis[(val - 1).clamp(0, 9)];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: done ? kSuccess.withAlpha(8) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: done ? kSuccess.withAlpha(60) : t.color.withAlpha(40))),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _selectedType = t.type),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(children: [
                  Text(emoji, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t.label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: t.color)),
                    Text(done ? 'Logged: $val/10' : 'Tap to record', style: TextStyle(fontSize: 11, color: done ? kSuccess : kTextLight)),
                  ])),
                  if (done) const Icon(Icons.check_circle, color: kSuccess, size: 22)
                  else Icon(Icons.chevron_right, color: t.color, size: 20),
                ]),
              ),
            ),
          );
        }),
        const SizedBox(height: 60),
      ],
    );
  }
}

// ── Full-page tracker with large emojis ──

class _TrackerPage extends StatefulWidget {
  final _Def def;
  final double value;
  final bool saved;
  final ValueChanged<double> onChanged;
  final ValueChanged<String> onNoteChanged;
  final VoidCallback onSave;
  const _TrackerPage({required this.def, required this.value, required this.saved,
    required this.onChanged, required this.onNoteChanged, required this.onSave});
  @override
  State<_TrackerPage> createState() => _TrackerPageState();
}

class _TrackerPageState extends State<_TrackerPage> {
  bool _showNote = false;
  final _noteCtrl = TextEditingController();
  @override
  void dispose() { _noteCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final t = widget.def;
    final score = widget.value.round().clamp(1, 10);
    final idx = (score - 1).clamp(0, 9);
    final emoji = t.emojis[idx];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      child: Column(children: [
        // Label
        Text(t.label, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: t.color)),
        const SizedBox(height: 4),
        Text(DateFormat('EEEE, d MMMM').format(DateTime.now()), style: TextStyle(fontSize: 12, color: kTextLight)),
        const SizedBox(height: 20),

        // Big emoji
        Text(emoji, style: const TextStyle(fontSize: 72)),
        const SizedBox(height: 8),

        // Score
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('$score', style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: t.color)),
          Text(' / 10', style: TextStyle(fontSize: 18, color: kTextLight)),
        ]),
        Text(score <= 3 ? t.lowLabel : score >= 8 ? t.highLabel : '', style: TextStyle(fontSize: 13, color: t.color)),
        const SizedBox(height: 20),

        // Emoji selector — 2 rows of 5
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(5, (i) => _EmojiBtn(emoji: t.emojis[i], number: i + 1, selected: idx == i, color: t.color,
            onTap: () => widget.onChanged((i + 1).toDouble())))),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(5, (i) => _EmojiBtn(emoji: t.emojis[i + 5], number: i + 6, selected: idx == i + 5, color: t.color,
            onTap: () => widget.onChanged((i + 6).toDouble())))),
        const SizedBox(height: 16),

        // Slider
        SliderTheme(
          data: SliderThemeData(activeTrackColor: t.color, inactiveTrackColor: t.color.withAlpha(30),
            thumbColor: t.color, overlayColor: t.color.withAlpha(20), trackHeight: 5,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10)),
          child: Slider(value: widget.value, min: 1, max: 10, divisions: 9, onChanged: widget.onChanged),
        ),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(t.lowLabel, style: TextStyle(fontSize: 10, color: kTextLight)),
            Text(t.highLabel, style: TextStyle(fontSize: 10, color: kTextLight)),
          ])),
        const SizedBox(height: 16),

        // Note
        TextButton.icon(
          onPressed: () => setState(() => _showNote = !_showNote),
          icon: Icon(_showNote ? Icons.expand_less : Icons.add_comment_outlined, size: 16),
          label: Text(_showNote ? 'Hide note' : 'Add a note', style: const TextStyle(fontSize: 12)),
        ),
        if (_showNote) Padding(
          padding: const EdgeInsets.only(top: 4),
          child: TextField(controller: _noteCtrl, maxLines: 3, style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(hintText: 'What\'s contributing to this?', alignLabelWithHint: true),
            onChanged: widget.onNoteChanged),
        ),
        const SizedBox(height: 20),

        // Save
        SizedBox(width: double.infinity, child: widget.saved
          ? OutlinedButton.icon(onPressed: null,
              icon: const Icon(Icons.check_circle, color: kSuccess),
              label: const Text('Saved', style: TextStyle(color: kSuccess)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: kSuccess)))
          : ElevatedButton.icon(onPressed: widget.onSave,
              icon: const Icon(Icons.save, color: Colors.white, size: 18),
              label: const Text('Save & Next'),
              style: ElevatedButton.styleFrom(backgroundColor: t.color, minimumSize: const Size.fromHeight(48))),
        ),
        const SizedBox(height: 8),
        Text('Swipe left/right to switch trackers', style: TextStyle(fontSize: 10, color: kTextLight)),
      ]),
    );
  }
}

class _EmojiBtn extends StatelessWidget {
  final String emoji; final int number; final bool selected; final Color color; final VoidCallback onTap;
  const _EmojiBtn({required this.emoji, required this.number, required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: selected ? 52 : 42, height: selected ? 58 : 48,
      decoration: BoxDecoration(
        color: selected ? color.withAlpha(25) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? color : kDivider, width: selected ? 2.5 : 1),
        boxShadow: selected ? [BoxShadow(color: color.withAlpha(30), blurRadius: 8)] : null,
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(emoji, style: TextStyle(fontSize: selected ? 24 : 18)),
        Text('$number', style: TextStyle(fontSize: selected ? 12 : 9, fontWeight: FontWeight.w700, color: selected ? color : kTextLight)),
      ]),
    ),
  );
}

// ── Trends Tab ──

class _TrendsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(padding: const EdgeInsets.all(14), children: [
      ..._trackers.map((t) => _TrendCard(def: t)),
      const SizedBox(height: 60),
    ]);
  }
}

class _TrendCard extends ConsumerWidget {
  final _Def def;
  const _TrendCard({required this.def});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<TrackingEntry>>(
      future: ref.read(trackingServiceProvider).getEntries(def.type, days: 30),
      builder: (context, snap) {
        final entries = snap.data ?? [];
        final latest = entries.isNotEmpty ? entries.last : null;
        final avg = entries.isNotEmpty ? (entries.map((e) => e.value).reduce((a, b) => a + b) / entries.length).toStringAsFixed(1) : '—';

        return Card(margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: kDivider)),
          child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(latest != null ? def.emojis[(latest.value.round() - 1).clamp(0, 9)] : '📊', style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Text(def.label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: def.color)),
              const Spacer(),
              if (latest != null) Text('${latest.value.round()}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: def.color)),
              Text('  avg $avg', style: TextStyle(fontSize: 10, color: kTextLight)),
            ]),
            if (entries.length >= 2) ...[
              const SizedBox(height: 10),
              SizedBox(height: 100, child: LineChart(LineChartData(
                minY: 1, maxY: 10,
                gridData: FlGridData(show: true, horizontalInterval: 3, getDrawingHorizontalLine: (_) => FlLine(color: kDivider, strokeWidth: 0.5), drawVerticalLine: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 20, interval: 3,
                    getTitlesWidget: (v, _) => Text('${v.toInt()}', style: TextStyle(fontSize: 8, color: kTextLight)))),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 18,
                    interval: (entries.length / 5).ceilToDouble().clamp(1, 100),
                    getTitlesWidget: (v, _) { final i = v.toInt(); if (i < 0 || i >= entries.length) return const SizedBox.shrink();
                      return Text(DateFormat('d/M').format(entries[i].timestamp), style: TextStyle(fontSize: 7, color: kTextLight)); })),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [LineChartBarData(
                  spots: entries.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.value)).toList(),
                  isCurved: true, color: def.color, barWidth: 2.5, dotData: FlDotData(show: entries.length < 15),
                  belowBarData: BarAreaData(show: true, gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [def.color.withAlpha(40), def.color.withAlpha(5)])))],
              ))),
            ] else Padding(padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(child: Text('Need 2+ entries', style: TextStyle(fontSize: 11, color: kTextLight)))),
          ])));
      },
    );
  }
}

// ── Reminders Tab — different times per tracker ──

class _RemindersTab extends StatefulWidget {
  const _RemindersTab();
  @override
  State<_RemindersTab> createState() => _RemindersTabState();
}

class _RemindersTabState extends State<_RemindersTab> {
  Map<String, Map<String, dynamic>> _reminders = {};
  bool _loaded = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('viva_tracking_reminders') ?? '{}';
    _reminders = (jsonDecode(raw) as Map<String, dynamic>).map((k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)));
    setState(() => _loaded = true);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('viva_tracking_reminders', jsonEncode(_reminders));
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator(color: kPrimary));

    return ListView(padding: const EdgeInsets.all(14), children: [
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: kPrimary.withAlpha(10), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          const Icon(Icons.notifications_active_outlined, color: kPrimary, size: 20), const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Tracking Reminders', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kText)),
            Text('Set different times for each tracker', style: TextStyle(fontSize: 11, color: kTextLight)),
          ])),
        ]),
      ),
      const SizedBox(height: 14),

      ..._trackers.map((t) {
        final r = _reminders[t.type];
        final enabled = r?['enabled'] == true;
        final time = r?['time'] as String? ?? '09:00';

        return Card(margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: enabled ? t.color.withAlpha(60) : kDivider)),
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), child: Column(children: [
            Row(children: [
              Text(t.emojis[4], style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(child: Text(t.label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.color))),
              Switch.adaptive(
                value: enabled,
                activeThumbColor: t.color,
                activeTrackColor: t.color.withAlpha(80),
                onChanged: (v) {
                  setState(() {
                    if (v) {
                      _reminders[t.type] = {'enabled': true, 'time': time};
                    } else {
                      _reminders.remove(t.type);
                    }
                  });
                  _save();
                },
              ),
            ]),
            if (enabled) Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: InkWell(
                onTap: () async {
                  final parts = time.split(':');
                  final picked = await showTimePicker(context: context,
                    initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])));
                  if (picked != null) {
                    final newTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                    setState(() => _reminders[t.type]!['time'] = newTime);
                    _save();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: t.color.withAlpha(10), borderRadius: BorderRadius.circular(8), border: Border.all(color: t.color.withAlpha(30))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.access_time, size: 16, color: t.color),
                    const SizedBox(width: 6),
                    Text(time, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: t.color)),
                    Text('  daily', style: TextStyle(fontSize: 11, color: kTextLight)),
                    const SizedBox(width: 4),
                    Icon(Icons.edit, size: 12, color: kTextLight),
                  ]),
                ),
              ),
            ),
          ])),
        );
      }),
      const SizedBox(height: 60),
    ]);
  }
}
