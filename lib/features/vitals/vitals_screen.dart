import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/services/tracking_service.dart';
import '../../core/api/api_client.dart';
import '../../core/offline/offline_write_queue.dart';

/// Audit Tier 4.1 (HIGH-J3) — best-effort dispatch for a tracking POST
/// that falls back to the OfflineWriteQueue on transport failure.
/// Returns `true` when delivered online, `false` when enqueued offline
/// (so the caller can surface a snackbar). 4xx/5xx errors still rethrow
/// so the form treats them as genuine input / permission failures.
Future<bool> _postTrackingOrQueue(Map<String, dynamic> body) async {
  try {
    await pApi.post('/patient-app/tracking', data: body);
    return true;
  } on DioException catch (e) {
    final isTransport = e.response == null;
    if (!isTransport) rethrow;
    await OfflineWriteQueue.instance.enqueue(
      method: 'POST',
      path: '/patient-app/tracking',
      body: body,
    );
    return false;
  }
}

void _showOfflineSaved(BuildContext ctx) {
  if (!ctx.mounted) return;
  ScaffoldMessenger.of(ctx).showSnackBar(
    const SnackBar(
      content: Text('Saved offline — will sync when online'),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

class VitalsScreen extends ConsumerStatefulWidget {
  const VitalsScreen({super.key});
  @override
  ConsumerState<VitalsScreen> createState() => _VitalsState();
}

class _VitalsState extends ConsumerState<VitalsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  void _refresh() => setState(() {});

  @override
  void initState() { super.initState(); _tabCtrl = TabController(length: 2, vsync: this); }
  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  void _addSingle(BuildContext context, String type, String label, String unit, {bool isBp = false}) {
    final ts = ref.read(trackingServiceProvider);
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _QuickAddSheet(ts: ts, type: type, label: label, unit: unit, isBp: isBp, onSaved: _refresh));
  }

  @override
  Widget build(BuildContext context) {
    final ts = ref.read(trackingServiceProvider);
    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        title: const Text('Vitals'),
        bottom: TabBar(controller: _tabCtrl, tabs: const [
          Tab(text: 'Readings'),
          Tab(text: 'Trends'),
        ]),
      ),
      body: TabBarView(controller: _tabCtrl, children: [
        // Readings tab
        ListView(
          padding: const EdgeInsets.all(14),
          children: [
            _VitalCard(ts: ts, type: 'weight', label: 'Weight', unit: 'kg', icon: Icons.monitor_weight_outlined,
              color: kWarning, normalMin: 50, normalMax: 100,
              onAdd: () => _addSingle(context, 'weight', 'Weight', 'kg'), onRefresh: _refresh),
            _BmiCard(ts: ts),
            _BpCard(ts: ts, onAdd: () => _addSingle(context, 'bp', 'Blood Pressure', 'mmHg', isBp: true), onRefresh: _refresh),
            _VitalCard(ts: ts, type: 'bloodSugar', label: 'Blood Sugar', unit: 'mmol/L', icon: Icons.water_drop_outlined,
              color: kInfo, normalMin: 4.0, normalMax: 7.8,
              onAdd: () => _addSingle(context, 'bloodSugar', 'Blood Sugar', 'mmol/L'), onRefresh: _refresh),
            _HeightCard(ts: ts, onAdd: () => _addSingle(context, 'height', 'Height', 'cm'), onRefresh: _refresh),
          const SizedBox(height: 20),
        ],
      ),
        // Trends tab
        _VitalsTrendsTab(ts: ts),
      ]),
    );
  }
}

// ── Generic Vital Card with graph + health range band ──

class _VitalCard extends StatelessWidget {
  final TrackingService ts;
  final String type, label, unit;
  final IconData icon;
  final Color color;
  final double normalMin, normalMax;
  final VoidCallback onAdd;
  final VoidCallback onRefresh;
  const _VitalCard({required this.ts, required this.type, required this.label, required this.unit,
    required this.icon, required this.color, required this.normalMin, required this.normalMax,
    required this.onAdd, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TrackingEntry>>(
      future: ts.getEntries(type, days: 90),
      builder: (context, snap) {
        final entries = snap.data ?? [];
        final latest = entries.isNotEmpty ? entries.last : null;
        final isOutside = latest != null && (latest.value < normalMin || latest.value > normalMax);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: kDivider)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                _IconBox(icon, color),
                const SizedBox(width: 10),
                Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
                const SizedBox(width: 6),
                // Add button inline
                GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(color: color.withAlpha(20), shape: BoxShape.circle),
                    child: Icon(Icons.add, size: 16, color: color),
                  ),
                ),
                const Spacer(),
                if (latest != null) Text('${latest.value.toStringAsFixed(1)} $unit',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: isOutside ? kError : color)),
              ]),
              _HealthBand(normalMin: normalMin, normalMax: normalMax, current: latest?.value, color: color, unit: unit),
              if (isOutside) _WarningChip(),
              if (entries.length >= 2)
                Padding(padding: const EdgeInsets.only(top: 10),
                  child: SizedBox(height: 130, child: _BandChart(entries: entries, color: color, normalMin: normalMin, normalMax: normalMax)))
              else if (entries.isEmpty)
                Padding(padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('No readings — tap + to add', style: TextStyle(fontSize: 11, color: kTextLight))),
              // Trend graph
              if (entries.length >= 2) ...[
                const SizedBox(height: 6),
                Row(children: [
                  Text('Trend (${entries.length} readings)', style: TextStyle(fontSize: 10, color: kTextLight)),
                  const Spacer(),
                  Text('${entries.first.timestamp.day}/${entries.first.timestamp.month} — ${entries.last.timestamp.day}/${entries.last.timestamp.month}',
                    style: TextStyle(fontSize: 9, color: kTextLight)),
                ]),
              ],
              // Recent entries with edit/delete
              if (entries.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 4),
                Text('Recent entries:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: kTextLight)),
                const SizedBox(height: 4),
                ...entries.reversed.take(8).map((e) => _EditableEntryRow(
                  entry: e, color: color, unit: unit, ts: ts, type: type, onChanged: onRefresh)),
              ],
            ]),
          ),
        );
      },
    );
  }
}

// ── BMI Card (calculated from weight + height) ──

class _BmiCard extends StatelessWidget {
  final TrackingService ts;
  const _BmiCard({required this.ts});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<List<TrackingEntry>>>(
      future: Future.wait<List<TrackingEntry>>([
        ts.getEntries('weight', days: 365),
        ts.getEntries('height', days: 365),
      ]),
      builder: (context, snap) {
        final grouped = snap.data ?? const <List<TrackingEntry>>[];
        final weights = grouped.isNotEmpty ? grouped[0] : const <TrackingEntry>[];
        final heights = grouped.length > 1 ? grouped[1] : const <TrackingEntry>[];
        final latestH = heights.isNotEmpty ? heights.last.value : null;
        if (latestH == null || latestH <= 0) {
          return Card(margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: kDivider)),
            child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
              _IconBox(Icons.calculate, kSuccess),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('BMI', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kSuccess)),
                Text('Add your height first to calculate BMI', style: TextStyle(fontSize: 11, color: kTextLight)),
              ])),
            ])),
          );
        }
        // Calculate BMI for each weight entry
        final hM = latestH / 100;
        final bmiEntries = weights.map((w) => TrackingEntry(type: 'bmi', value: w.value / (hM * hM), timestamp: w.timestamp)).toList();
        final latest = bmiEntries.isNotEmpty ? bmiEntries.last : null;
        String cat = ''; Color catColor = kTextLight;
        if (latest != null) {
          if (latest.value < 18.5) { cat = 'Underweight'; catColor = kInfo; }
          else if (latest.value < 25) { cat = 'Normal'; catColor = kSuccess; }
          else if (latest.value < 30) { cat = 'Overweight'; catColor = kWarning; }
          else { cat = 'Obese'; catColor = kError; }
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: kDivider)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                _IconBox(Icons.calculate, kSuccess),
                const SizedBox(width: 10),
                const Text('BMI', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kSuccess)),
                if (cat.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: catColor.withAlpha(20), borderRadius: BorderRadius.circular(6)),
                    child: Text(cat, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: catColor))),
                ],
                const Spacer(),
                if (latest != null) Text(latest.value.toStringAsFixed(1),
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: catColor)),
              ]),
              _HealthBand(normalMin: 18.5, normalMax: 25, current: latest?.value, color: kSuccess, unit: ''),
              if (bmiEntries.length >= 2) Padding(
                padding: const EdgeInsets.only(top: 10),
                child: SizedBox(height: 100, child: _BandChart(entries: bmiEntries, color: kSuccess, normalMin: 18.5, normalMax: 25))),
            ]),
          ),
        );
      },
    );
  }
}

// ── Blood Pressure Card (systolic + diastolic with bands) ──

class _BpCard extends StatelessWidget {
  final TrackingService ts;
  final VoidCallback onAdd;
  final VoidCallback onRefresh;
  const _BpCard({required this.ts, required this.onAdd, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<List<TrackingEntry>>>(
      future: Future.wait<List<TrackingEntry>>([
        ts.getEntries('bpSystolic', days: 90),
        ts.getEntries('bpDiastolic', days: 90),
      ]),
      builder: (context, snap) {
        final grouped = snap.data ?? const <List<TrackingEntry>>[];
        final sys = grouped.isNotEmpty ? grouped[0] : const <TrackingEntry>[];
        final dia = grouped.length > 1 ? grouped[1] : const <TrackingEntry>[];
        final latestSys = sys.isNotEmpty ? sys.last.value : null;
        final latestDia = dia.isNotEmpty ? dia.last.value : null;
        String cat = ''; Color catColor = kTextLight;
        if (latestSys != null) {
          if (latestSys < 120) { cat = 'Normal'; catColor = kSuccess; }
          else if (latestSys < 130) { cat = 'Elevated'; catColor = kWarning; }
          else if (latestSys < 140) { cat = 'High Stage 1'; catColor = const Color(0xFFE65100); }
          else { cat = 'High Stage 2'; catColor = kError; }
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: kDivider)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                _IconBox(Icons.favorite_outline, kError),
                const SizedBox(width: 10),
                const Text('Blood Pressure', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kError)),
                const SizedBox(width: 6),
                GestureDetector(onTap: onAdd, child: Container(width: 24, height: 24,
                  decoration: BoxDecoration(color: kError.withAlpha(20), shape: BoxShape.circle),
                  child: const Icon(Icons.add, size: 16, color: kError))),
                if (cat.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: catColor.withAlpha(20), borderRadius: BorderRadius.circular(6)),
                    child: Text(cat, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: catColor))),
                ],
                const Spacer(),
                if (latestSys != null) Text('${latestSys.round()}/${latestDia?.round() ?? '—'}',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: catColor)),
                if (latestSys != null) Text(' mmHg', style: TextStyle(fontSize: 9, color: kTextLight)),
              ]),
              // Health band for systolic
              _HealthBand(normalMin: 90, normalMax: 120, current: latestSys, color: kError, unit: 'mmHg'),
              if (sys.length >= 2) Padding(
                padding: const EdgeInsets.only(top: 10),
                child: SizedBox(height: 100, child: LineChart(LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, interval: 30,
                      getTitlesWidget: (v, _) => Text('${v.toInt()}', style: TextStyle(fontSize: 8, color: kTextLight)))),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 16,
                      interval: (sys.length / 4).ceilToDouble().clamp(1, 100),
                      getTitlesWidget: (v, _) {
                        final i = v.toInt(); if (i < 0 || i >= sys.length) return const SizedBox.shrink();
                        return Text(DateFormat('d/M').format(sys[i].timestamp), style: TextStyle(fontSize: 7, color: kTextLight));
                      })),
                  ),
                  borderData: FlBorderData(show: false),
                  rangeAnnotations: RangeAnnotations(horizontalRangeAnnotations: [
                    HorizontalRangeAnnotation(y1: 90, y2: 120, color: kSuccess.withAlpha(15)),
                  ]),
                  lineBarsData: [
                    LineChartBarData(spots: sys.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.value)).toList(),
                      isCurved: true, color: kError, barWidth: 2.5, dotData: const FlDotData(show: false)),
                    if (dia.length >= 2) LineChartBarData(
                      spots: dia.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.value)).toList(),
                      isCurved: true, color: kError.withAlpha(100), barWidth: 1.5, dotData: const FlDotData(show: false), dashArray: [4, 3]),
                  ],
                )))),
              if (sys.length >= 2) Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(width: 14, height: 2.5, color: kError),
                  Text(' Systolic  ', style: TextStyle(fontSize: 9, color: kTextLight)),
                  Container(width: 14, height: 1.5, color: kError.withAlpha(100)),
                  Text(' Diastolic  ', style: TextStyle(fontSize: 9, color: kTextLight)),
                  Container(width: 14, height: 8, color: kSuccess.withAlpha(15)),
                  Text(' Normal', style: TextStyle(fontSize: 9, color: kTextLight)),
                ]),
              ),
              if (sys.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('No readings — tap + to add', style: TextStyle(fontSize: 11, color: kTextLight))),
              // Recent BP entries with delete
              if (sys.isNotEmpty) ...[
                const SizedBox(height: 8), const Divider(height: 1), const SizedBox(height: 4),
                Text('Recent entries:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: kTextLight)),
                const SizedBox(height: 4),
                ...sys.reversed.take(5).toList().asMap().entries.map((e) {
                  final i = e.key;
                  final s = e.value;
                  final d = i < dia.reversed.take(5).length ? dia.reversed.take(5).toList()[i] : null;
                  final dateStr = DateFormat('d MMM HH:mm').format(s.timestamp.toLocal());
                  return Padding(padding: const EdgeInsets.only(bottom: 3), child: Row(children: [
                    SizedBox(width: 70, child: Text(dateStr, style: TextStyle(fontSize: 9, color: kTextLight))),
                    Text('${s.value.round()}/${d?.value.round() ?? '—'} mmHg',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kError)),
                    const Spacer(),
                    GestureDetector(onTap: () async {
                      await ts.deleteEntry('bpSystolic', s.value, s.timestamp);
                      if (d != null) await ts.deleteEntry('bpDiastolic', d.value, d.timestamp);
                      onRefresh();
                    }, child: const Icon(Icons.delete_outline, size: 14, color: kError)),
                  ]));
                }),
              ],
            ]),
          ),
        );
      },
    );
  }
}

// ── Health Range Band ──

class _HealthBand extends StatelessWidget {
  final double normalMin, normalMax;
  final double? current;
  final Color color;
  final String unit;
  const _HealthBand({required this.normalMin, required this.normalMax, this.current, required this.color, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Band
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 10,
            child: Row(children: [
              Expanded(flex: 20, child: Container(color: kInfo.withAlpha(30))), // low
              Expanded(flex: 60, child: Container(color: kSuccess.withAlpha(40))), // normal
              Expanded(flex: 20, child: Container(color: kError.withAlpha(30))), // high
            ]),
          ),
        ),
        const SizedBox(height: 2),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Low', style: TextStyle(fontSize: 8, color: kInfo)),
          Text('Normal (${normalMin.toStringAsFixed(normalMin == normalMin.roundToDouble() ? 0 : 1)}–${normalMax.toStringAsFixed(normalMax == normalMax.roundToDouble() ? 0 : 1)}${unit.isNotEmpty ? ' $unit' : ''})',
            style: TextStyle(fontSize: 8, color: kSuccess, fontWeight: FontWeight.w600)),
          Text('High', style: TextStyle(fontSize: 8, color: kError)),
        ]),
      ]),
    );
  }
}

class _WarningChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(children: [
      const Icon(Icons.warning_amber, size: 13, color: kError), const SizedBox(width: 4),
      Text('Outside normal range', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: kError)),
    ]),
  );
}

// ── Chart with health range band overlay ──

class _BandChart extends StatelessWidget {
  final List<TrackingEntry> entries;
  final Color color;
  final double normalMin, normalMax;
  const _BandChart({required this.entries, required this.color, required this.normalMin, required this.normalMax});

  @override
  Widget build(BuildContext context) {
    return LineChart(LineChartData(
      gridData: const FlGridData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28,
          interval: (normalMax - normalMin) / 2,
          getTitlesWidget: (v, _) => Text(v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1), style: TextStyle(fontSize: 8, color: kTextLight)))),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 16,
          interval: (entries.length / 4).ceilToDouble().clamp(1, 100),
          getTitlesWidget: (v, _) {
            final i = v.toInt(); if (i < 0 || i >= entries.length) return const SizedBox.shrink();
            return Text(DateFormat('d/M').format(entries[i].timestamp), style: TextStyle(fontSize: 7, color: kTextLight));
          })),
      ),
      borderData: FlBorderData(show: false),
      rangeAnnotations: RangeAnnotations(horizontalRangeAnnotations: [
        HorizontalRangeAnnotation(y1: normalMin, y2: normalMax, color: kSuccess.withAlpha(15)),
      ]),
      lineBarsData: [LineChartBarData(
        spots: entries.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.value)).toList(),
        isCurved: true, color: color, barWidth: 2.5,
        dotData: FlDotData(show: entries.length < 15),
        belowBarData: BarAreaData(show: true, color: color.withAlpha(15)),
      )],
    ));
  }
}

// ── Height Card (single value, no trend) ──

class _HeightCard extends StatelessWidget {
  final TrackingService ts;
  final VoidCallback onAdd;
  final VoidCallback onRefresh;
  const _HeightCard({required this.ts, required this.onAdd, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TrackingEntry>>(
      future: ts.getEntries('height', days: 365),
      builder: (context, snap) {
        final entries = snap.data ?? [];
        final latest = entries.isNotEmpty ? entries.last : null;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: kDivider)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              const _IconBox(Icons.height, Color(0xFF5C6BC0)),
              const SizedBox(width: 10),
              const Text('Height', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF5C6BC0))),
              const SizedBox(width: 6),
              GestureDetector(onTap: onAdd, child: Container(width: 24, height: 24,
                decoration: BoxDecoration(color: const Color(0xFF5C6BC0).withAlpha(20), shape: BoxShape.circle),
                child: const Icon(Icons.edit, size: 14, color: Color(0xFF5C6BC0)))),
              const Spacer(),
              Text(latest != null ? '${latest.value.toStringAsFixed(0)} cm' : 'Not set',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: latest != null ? const Color(0xFF5C6BC0) : kTextLight)),
            ]),
          ),
        );
      },
    );
  }
}

// ── Vitals Trends Tab (like daily check-in trends) ──

class _VitalsTrendsTab extends StatelessWidget {
  final TrackingService ts;
  const _VitalsTrendsTab({required this.ts});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _VitalTrendCard(ts: ts, type: 'weight', label: 'Weight', unit: 'kg', color: kWarning, icon: Icons.monitor_weight_outlined, normalMin: 50, normalMax: 100),
        _BpTrendCard(ts: ts),
        _VitalTrendCard(ts: ts, type: 'bloodSugar', label: 'Blood Sugar', unit: 'mmol/L', color: kInfo, icon: Icons.water_drop_outlined, normalMin: 4.0, normalMax: 7.8),
        const SizedBox(height: 60),
      ],
    );
  }
}

class _VitalTrendCard extends StatelessWidget {
  final TrackingService ts;
  final String type, label, unit;
  final Color color;
  final IconData icon;
  final double normalMin, normalMax;
  const _VitalTrendCard({required this.ts, required this.type, required this.label, required this.unit,
    required this.color, required this.icon, required this.normalMin, required this.normalMax});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TrackingEntry>>(
      future: ts.getEntries(type, days: 90),
      builder: (context, snap) {
        final entries = snap.data ?? [];
        final latest = entries.isNotEmpty ? entries.last : null;
        final avg = entries.isNotEmpty ? (entries.map((e) => e.value).reduce((a, b) => a + b) / entries.length).toStringAsFixed(1) : '—';
        final min = entries.isNotEmpty ? entries.map((e) => e.value).reduce((a, b) => a < b ? a : b).toStringAsFixed(1) : '—';
        final max = entries.isNotEmpty ? entries.map((e) => e.value).reduce((a, b) => a > b ? a : b).toStringAsFixed(1) : '—';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: kDivider)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Header
              Row(children: [
                _IconBox(icon, color),
                const SizedBox(width: 10),
                Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
                const Spacer(),
                if (latest != null) Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${latest.value.toStringAsFixed(1)} $unit', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
                  Text('avg: $avg', style: TextStyle(fontSize: 10, color: kTextLight)),
                ]),
              ]),
              Text('${entries.length} readings (90 days)', style: TextStyle(fontSize: 10, color: kTextLight)),
              // Stats row
              if (entries.length >= 2) Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  _StatPill('Min', min, color),
                  _StatPill('Avg', avg, color),
                  _StatPill('Max', max, color),
                ]),
              ),
              // Chart
              if (entries.length >= 2) Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SizedBox(height: 140, child: _BandChart(entries: entries, color: color, normalMin: normalMin, normalMax: normalMax)),
              ),
              if (entries.length < 2) Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(child: Text('Need 2+ entries to show trend', style: TextStyle(fontSize: 11, color: kTextLight)))),
              // Recent entries
              if (entries.isNotEmpty) ...[
                const SizedBox(height: 8), const Divider(height: 1), const SizedBox(height: 6),
                ...entries.reversed.take(5).map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(children: [
                    SizedBox(width: 70, child: Text(DateFormat('d MMM').format(e.timestamp), style: TextStyle(fontSize: 10, color: kTextLight))),
                    Container(width: 40, height: 18, decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(4)),
                      child: Center(child: Text(e.value.toStringAsFixed(1), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)))),
                    if (e.note != null && e.note!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Expanded(child: Text(e.note!, style: TextStyle(fontSize: 9, color: kTextLight), overflow: TextOverflow.ellipsis)),
                    ],
                  ]),
                )),
              ],
            ]),
          ),
        );
      },
    );
  }
}

class _BpTrendCard extends StatelessWidget {
  final TrackingService ts;
  const _BpTrendCard({required this.ts});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<List<TrackingEntry>>>(
      future: Future.wait<List<TrackingEntry>>([
        ts.getEntries('bpSystolic', days: 90),
        ts.getEntries('bpDiastolic', days: 90),
      ]),
      builder: (context, snap) {
        final grouped = snap.data ?? const <List<TrackingEntry>>[];
        final sys = grouped.isNotEmpty ? grouped[0] : const <TrackingEntry>[];
        final dia = grouped.length > 1 ? grouped[1] : const <TrackingEntry>[];
        final latestSys = sys.isNotEmpty ? sys.last.value : null;
        final latestDia = dia.isNotEmpty ? dia.last.value : null;
        final avgSys = sys.isNotEmpty ? (sys.map((e) => e.value).reduce((a, b) => a + b) / sys.length).toStringAsFixed(0) : '—';
        final avgDia = dia.isNotEmpty ? (dia.map((e) => e.value).reduce((a, b) => a + b) / dia.length).toStringAsFixed(0) : '—';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: kDivider)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                _IconBox(Icons.favorite_outline, kError),
                const SizedBox(width: 10),
                const Text('Blood Pressure', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kError)),
                const Spacer(),
                if (latestSys != null) Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${latestSys.round()}/${latestDia?.round() ?? '—'}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kError)),
                  Text('avg: $avgSys/$avgDia', style: TextStyle(fontSize: 10, color: kTextLight)),
                ]),
              ]),
              Text('${sys.length} readings (90 days)', style: TextStyle(fontSize: 10, color: kTextLight)),
              // Dual chart
              if (sys.length >= 2) Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SizedBox(height: 140, child: LineChart(LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, interval: 20,
                      getTitlesWidget: (v, _) => Text('${v.toInt()}', style: TextStyle(fontSize: 8, color: kTextLight)))),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 16,
                      interval: (sys.length / 4).ceilToDouble().clamp(1, 100),
                      getTitlesWidget: (v, _) {
                        final i = v.toInt(); if (i < 0 || i >= sys.length) return const SizedBox.shrink();
                        return Text(DateFormat('d/M').format(sys[i].timestamp), style: TextStyle(fontSize: 7, color: kTextLight));
                      })),
                  ),
                  borderData: FlBorderData(show: false),
                  rangeAnnotations: RangeAnnotations(horizontalRangeAnnotations: [
                    HorizontalRangeAnnotation(y1: 90, y2: 120, color: kSuccess.withAlpha(15)),
                  ]),
                  lineBarsData: [
                    LineChartBarData(spots: sys.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.value)).toList(),
                      isCurved: true, color: kError, barWidth: 2.5, dotData: FlDotData(show: sys.length < 15)),
                    if (dia.length >= 2) LineChartBarData(
                      spots: dia.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.value)).toList(),
                      isCurved: true, color: kError.withAlpha(100), barWidth: 1.5, dotData: const FlDotData(show: false), dashArray: [4, 3]),
                  ],
                ))),
              ),
              if (sys.length >= 2) Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(width: 14, height: 2.5, color: kError),
                  Text(' Systolic  ', style: TextStyle(fontSize: 9, color: kTextLight)),
                  Container(width: 14, height: 1.5, color: kError.withAlpha(100)),
                  Text(' Diastolic  ', style: TextStyle(fontSize: 9, color: kTextLight)),
                  Container(width: 14, height: 8, color: kSuccess.withAlpha(15)),
                  Text(' Normal', style: TextStyle(fontSize: 9, color: kTextLight)),
                ]),
              ),
              if (sys.length < 2) Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(child: Text('Need 2+ entries', style: TextStyle(fontSize: 11, color: kTextLight)))),
            ]),
          ),
        );
      },
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatPill(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
    Text(label, style: TextStyle(fontSize: 9, color: kTextLight)),
  ]);
}

class _IconBox extends StatelessWidget {
  final IconData icon; final Color color;
  const _IconBox(this.icon, this.color);
  @override
  Widget build(BuildContext context) => Container(width: 32, height: 32,
    decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(8)),
    child: Icon(icon, color: color, size: 18));
}

// ── Add Vital Sheet ──

class _AddVitalSheet extends StatefulWidget {
  final TrackingService ts; final VoidCallback onSaved;
  const _AddVitalSheet({required this.ts, required this.onSaved});
  @override
  State<_AddVitalSheet> createState() => _AddVitalSheetState();
}

class _AddVitalSheetState extends State<_AddVitalSheet> {
  String _type = 'weight';
  final _v1 = TextEditingController();
  final _v2 = TextEditingController();
  bool _saving = false;

  static const _types = [
    ('weight', 'Weight (kg)', Icons.monitor_weight_outlined, kWarning),
    ('height', 'Height (cm)', Icons.height, Color(0xFF5C6BC0)),
    ('bp', 'Blood Pressure', Icons.favorite_outline, kError),
    ('bloodSugar', 'Blood Sugar', Icons.water_drop_outlined, kInfo),
  ];

  @override
  void dispose() { _v1.dispose(); _v2.dispose(); super.dispose(); }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      bool? delivered;
      if (_type == 'bp') {
        final s = double.tryParse(_v1.text.trim()); final d = double.tryParse(_v2.text.trim());
        if (s == null || d == null) { setState(() => _saving = false); return; }
        await widget.ts.addEntry(TrackingEntry(type: 'bpSystolic', value: s));
        await widget.ts.addEntry(TrackingEntry(type: 'bpDiastolic', value: d));
        delivered = await _postTrackingOrQueue({'entries': [{'type': 'bpSystolic', 'value': s}, {'type': 'bpDiastolic', 'value': d}]});
      } else {
        final v = double.tryParse(_v1.text.trim()); if (v == null) { setState(() => _saving = false); return; }
        await widget.ts.addEntry(TrackingEntry(type: _type, value: v));
        delivered = await _postTrackingOrQueue({'entries': [{'type': _type, 'value': v}]});
      }
      if (mounted) {
        if (delivered == false) _showOfflineSaved(context);
        Navigator.pop(context); widget.onSaved();
      }
    } on DioException catch (e) {
      if (mounted) {
        final msg = e.response?.data is Map && (e.response!.data as Map)['message'] is String
            ? (e.response!.data as Map)['message'] as String
            : (e.message ?? 'Please try again');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save: $msg')));
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Add Reading', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: kText)),
        const Divider(), const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: _types.map((t) => ChoiceChip(
          avatar: Icon(t.$3, size: 16, color: t.$4), label: Text(t.$2, style: const TextStyle(fontSize: 11)),
          selected: _type == t.$1, selectedColor: t.$4.withAlpha(25),
          onSelected: (_) => setState(() { _type = t.$1; _v1.clear(); _v2.clear(); }),
        )).toList()),
        const SizedBox(height: 14),
        if (_type == 'bp') Row(children: [
          Expanded(child: TextField(controller: _v1, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Systolic', suffixText: 'mmHg'))),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('/', style: TextStyle(fontSize: 24, color: kTextLight))),
          Expanded(child: TextField(controller: _v2, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Diastolic', suffixText: 'mmHg'))),
        ]) else
          TextField(controller: _v1, keyboardType: TextInputType.number, decoration: InputDecoration(
            labelText: _type == 'weight' ? 'Weight' : _type == 'height' ? 'Height' : 'Value',
            suffixText: _type == 'weight' ? 'kg' : _type == 'height' ? 'cm' : 'mmol/L')),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: _saving ? null : _save, child: _saving
          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : const Text('Save')),
      ])),
    );
  }
}

// ── Quick Add Sheet (for individual vital types) ──

class _QuickAddSheet extends StatefulWidget {
  final TrackingService ts;
  final String type, label, unit;
  final bool isBp;
  final VoidCallback onSaved;
  const _QuickAddSheet({required this.ts, required this.type, required this.label, required this.unit,
    this.isBp = false, required this.onSaved});
  @override
  State<_QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<_QuickAddSheet> {
  final _v1 = TextEditingController();
  final _v2 = TextEditingController();
  bool _saving = false;
  bool _isDraft = false;

  @override
  void dispose() { _v1.dispose(); _v2.dispose(); super.dispose(); }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      bool? delivered;
      if (widget.isBp) {
        final s = double.tryParse(_v1.text.trim()); final d = double.tryParse(_v2.text.trim());
        if (s == null || d == null) { setState(() => _saving = false); return; }
        final notePrefix = _isDraft ? '[DRAFT] ' : '';
        await widget.ts.addEntry(TrackingEntry(type: 'bpSystolic', value: s, note: '${notePrefix}systolic'));
        await widget.ts.addEntry(TrackingEntry(type: 'bpDiastolic', value: d, note: '${notePrefix}diastolic'));
        delivered = await _postTrackingOrQueue({'entries': [
          {'type': 'bpSystolic', 'value': s, 'note': '${notePrefix}systolic'},
          {'type': 'bpDiastolic', 'value': d, 'note': '${notePrefix}diastolic'},
        ]});
      } else {
        final v = double.tryParse(_v1.text.trim()); if (v == null) { setState(() => _saving = false); return; }
        final notePrefix = _isDraft ? '[DRAFT] ' : '';
        await widget.ts.addEntry(TrackingEntry(type: widget.type, value: v, note: notePrefix.isNotEmpty ? notePrefix : null));
        delivered = await _postTrackingOrQueue({'entries': [
          {'type': widget.type, 'value': v, 'note': notePrefix.isNotEmpty ? notePrefix : null},
        ]});
      }
      if (mounted) {
        if (delivered == false) _showOfflineSaved(context);
        Navigator.pop(context); widget.onSaved();
      }
    } on DioException catch (e) {
      if (mounted) {
        final msg = e.response?.data is Map && (e.response!.data as Map)['message'] is String
            ? (e.response!.data as Map)['message'] as String
            : (e.message ?? 'Please try again');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save: $msg')));
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Add ${widget.label}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: kText)),
        const Divider(), const SizedBox(height: 8),
        if (widget.isBp) Row(children: [
          Expanded(child: TextField(controller: _v1, keyboardType: TextInputType.number, autofocus: true,
            decoration: const InputDecoration(labelText: 'Systolic', suffixText: 'mmHg'))),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('/', style: TextStyle(fontSize: 24, color: kTextLight))),
          Expanded(child: TextField(controller: _v2, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Diastolic', suffixText: 'mmHg'))),
        ]) else
          TextField(controller: _v1, keyboardType: TextInputType.number, autofocus: true,
            decoration: InputDecoration(labelText: widget.label, suffixText: widget.unit)),
        const SizedBox(height: 12),
        // Draft vs Save toggle
        Row(children: [
          Expanded(child: ElevatedButton(
            onPressed: _saving ? null : () { _isDraft = false; _save(); },
            style: ElevatedButton.styleFrom(backgroundColor: kPrimary),
            child: _saving && !_isDraft
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Save', style: TextStyle(fontSize: 13)),
          )),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton(
            onPressed: _saving ? null : () { _isDraft = true; _save(); },
            style: OutlinedButton.styleFrom(foregroundColor: kWarning, side: const BorderSide(color: kWarning)),
            child: _saving && _isDraft
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: kWarning, strokeWidth: 2))
              : const Text('Save as Draft', style: TextStyle(fontSize: 13)),
          )),
        ]),
        const SizedBox(height: 4),
        Center(child: Text('Drafts can be edited later', style: TextStyle(fontSize: 10, color: kTextLight))),
      ])),
    );
  }
}

// ── Editable Entry Row ──

class _EditableEntryRow extends StatefulWidget {
  final TrackingEntry entry;
  final Color color;
  final String unit;
  final TrackingService ts;
  final String type;
  final VoidCallback onChanged;
  const _EditableEntryRow({required this.entry, required this.color, required this.unit,
    required this.ts, required this.type, required this.onChanged});
  @override
  State<_EditableEntryRow> createState() => _EditableEntryRowState();
}

class _EditableEntryRowState extends State<_EditableEntryRow> {
  bool _editing = false;
  late final TextEditingController _ctrl;

  bool get _isDraft => widget.entry.note?.contains('[DRAFT]') ?? false;

  @override
  void initState() { super.initState(); _ctrl = TextEditingController(text: widget.entry.value.toStringAsFixed(1)); }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final dateStr = DateFormat('d MMM HH:mm').format(e.timestamp.toLocal());

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(children: [
        SizedBox(width: 70, child: Text(dateStr, style: TextStyle(fontSize: 9, color: kTextLight))),
        if (_editing) ...[
          SizedBox(width: 60, child: TextField(controller: _ctrl, keyboardType: TextInputType.number,
            style: TextStyle(fontSize: 12, color: widget.color), decoration: InputDecoration(isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4))))),
          const SizedBox(width: 4),
          GestureDetector(onTap: () async {
            final newVal = double.tryParse(_ctrl.text.trim());
            if (newVal == null) return;
            // Update local — tracking service doesn't have update, so we add new + note the edit
            await widget.ts.addEntry(TrackingEntry(type: widget.type, value: newVal, note: 'Edited'));
            try {
              final delivered = await _postTrackingOrQueue({'entries': [
                {'type': widget.type, 'value': newVal, 'note': 'Edited from ${e.value.toStringAsFixed(1)}'}
              ]});
              if (delivered == false && context.mounted) _showOfflineSaved(context);
            } on DioException catch (err) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Could not save edit: ${err.message ?? 'unknown'}'),
                ));
              }
            }
            setState(() => _editing = false);
            widget.onChanged();
          }, child: const Icon(Icons.check, size: 16, color: kSuccess)),
          const SizedBox(width: 4),
          GestureDetector(onTap: () => setState(() => _editing = false),
            child: const Icon(Icons.close, size: 16, color: kTextLight)),
        ] else ...[
          Text('${e.value.toStringAsFixed(1)} ${widget.unit}',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: widget.color)),
          if (_isDraft) ...[
            const SizedBox(width: 4),
            Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(color: kWarning.withAlpha(20), borderRadius: BorderRadius.circular(3)),
              child: const Text('DRAFT', style: TextStyle(fontSize: 7, fontWeight: FontWeight.w700, color: kWarning))),
          ],
          const Spacer(),
          // Edit button (all entries)
          GestureDetector(onTap: () => setState(() => _editing = true),
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text('Edit', style: TextStyle(fontSize: 9, color: widget.color)))),
          // Delete button (all entries)
          GestureDetector(onTap: () async {
            await widget.ts.deleteEntry(widget.type, e.value, e.timestamp);
            widget.onChanged();
          },
            child: const Padding(padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.delete_outline, size: 14, color: kError))),
        ],
      ]),
    );
  }
}
