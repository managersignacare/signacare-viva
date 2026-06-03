import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/services/tracking_service.dart';

/// Medications — view-only from desktop + adherence tracking.
class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});
  @override
  ConsumerState<RemindersScreen> createState() => _RemindersState();
}

class _RemindersState extends ConsumerState<RemindersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        title: const Text('Medications'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: 'Current Medications'),
            Tab(text: 'Adherence'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [_MedsListTab(), _AdherenceTab()],
      ),
    );
  }
}

// ── Current Medications (read-only from desktop) ──

class _MedsListTab extends StatelessWidget {
  Future<List<Map<String, dynamic>>> _fetch() async {
    try {
      final pid = await pApi.patientId;
      if (pid == null) return [];
      final data = await pApi.get('/patient-app/medications/$pid');
      final list = (data as Map)['medications'] as List? ?? [];
      return list
          .map((j) => Map<String, dynamic>.from(j as Map))
          .where((m) => m['status'] == 'active')
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _fetch(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: kPrimary),
          );
        }
        final meds = snap.data ?? [];
        if (meds.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.medication_outlined,
                  size: 48,
                  color: kTextLight.withAlpha(100),
                ),
                const SizedBox(height: 12),
                const Text(
                  'No active medications',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: kText,
                  ),
                ),
                Text(
                  'Medications prescribed by your clinician appear here',
                  style: TextStyle(fontSize: 12, color: kTextLight),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kInfo.withAlpha(10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: kInfo),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'These medications are managed by your care team. View only.',
                      style: TextStyle(fontSize: 10, color: kTextLight),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            ...meds.map((m) => _MedCard(med: m)),
          ],
        );
      },
    );
  }
}

class _MedCard extends ConsumerWidget {
  final Map<String, dynamic> med;
  const _MedCard({required this.med});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = med['drugLabel'] ?? med['genericName'] ?? 'Medication';
    final dose = '${med['dose'] ?? ''} ${med['route'] ?? ''}'.trim();
    final freq = med['frequency'] ?? '';
    final ts = ref.read(trackingServiceProvider);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: kDivider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: kMeds.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.medication, color: kMeds, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.toString(),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: kText,
                        ),
                      ),
                      if (dose.isNotEmpty)
                        Text(
                          dose,
                          style: TextStyle(fontSize: 12, color: kTextLight),
                        ),
                      if (freq.toString().isNotEmpty)
                        Text(
                          freq.toString(),
                          style: TextStyle(fontSize: 11, color: kTextLight),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            // Medication info link
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: InkWell(
                onTap: () async {
                  final searchName = Uri.encodeComponent(
                    name.toString().split(' ').first.toLowerCase(),
                  );
                  final uri = Uri.parse(
                    'https://www.nps.org.au/medicine-finder?q=$searchName',
                  );
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline, size: 14, color: kInfo),
                    const SizedBox(width: 4),
                    Text(
                      'Medicine info (NPS MedicineWise)',
                      style: TextStyle(
                        fontSize: 11,
                        color: kInfo,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Today's adherence response
            FutureBuilder<double?>(
              future: ts.getTodayValue('med_${name.toString().hashCode}'),
              builder: (_, snap) {
                final taken = snap.data;
                if (taken != null) {
                  return Row(
                    children: [
                      Icon(
                        taken >= 1 ? Icons.check_circle : Icons.cancel,
                        color: taken >= 1 ? kSuccess : kWarning,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        taken >= 1 ? 'Taken today' : 'Missed today',
                        style: TextStyle(
                          fontSize: 12,
                          color: taken >= 1 ? kSuccess : kWarning,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _respond(ref, name.toString(), true),
                        icon: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 16,
                        ),
                        label: const Text(
                          'Taken',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kSuccess,
                          minimumSize: const Size(0, 34),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _respond(ref, name.toString(), false),
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text(
                          'Missed',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kWarning,
                          side: const BorderSide(color: kWarning),
                          minimumSize: const Size(0, 34),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _respond(WidgetRef ref, String medName, bool taken) async {
    final ts = ref.read(trackingServiceProvider);
    await ts.addEntry(
      TrackingEntry(
        type: 'med_${medName.hashCode}',
        value: taken ? 1.0 : 0.0,
        note: medName,
      ),
    );
    await ts.addEntry(
      TrackingEntry(type: 'meds', value: taken ? 1.0 : 0.0, note: medName),
    );
    try {
      await pApi.post(
        '/patient-app/tracking',
        data: {
          'entries': [
            {'type': 'meds', 'value': taken ? 1 : 0, 'note': medName},
          ],
        },
      );
    } catch (_) {}
    // Force rebuild
    (ref as dynamic).invalidateSelf?.call();
  }
}

// ── Adherence Tab (visualization over time) ──

class _AdherenceTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ts = ref.read(trackingServiceProvider);
    return FutureBuilder<List<TrackingEntry>>(
      future: ts.getEntries('meds', days: 30),
      builder: (context, snap) {
        final entries = snap.data ?? [];
        if (entries.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.bar_chart_outlined,
                  size: 48,
                  color: kTextLight.withAlpha(100),
                ),
                const SizedBox(height: 12),
                const Text(
                  'No adherence data yet',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: kText,
                  ),
                ),
                Text(
                  'Respond to medication prompts to track adherence',
                  style: TextStyle(fontSize: 12, color: kTextLight),
                ),
              ],
            ),
          );
        }

        // Calculate stats
        final taken = entries.where((e) => e.value >= 1).length;
        final missed = entries.where((e) => e.value < 1).length;
        final total = taken + missed;
        final rate = total > 0 ? (taken / total * 100).round() : 0;
        final rateColor = rate >= 80
            ? kSuccess
            : rate >= 60
            ? kWarning
            : kError;

        // Group by day for chart
        final Map<String, _DayStat> byDay = {};
        for (final e in entries) {
          final key = DateFormat('yyyy-MM-dd').format(e.timestamp);
          byDay[key] ??= _DayStat();
          if (e.value >= 1) {
            byDay[key]!.taken++;
          } else {
            byDay[key]!.missed++;
          }
        }
        final days = byDay.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));

        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            // Summary
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: kDivider),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Donut
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 80,
                            height: 80,
                            child: CircularProgressIndicator(
                              value: rate / 100,
                              strokeWidth: 8,
                              backgroundColor: kDivider,
                              color: rateColor,
                            ),
                          ),
                          Text(
                            '$rate%',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: rateColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '30-Day Adherence',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: kText,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                size: 14,
                                color: kSuccess,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$taken taken',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: kSuccess,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.cancel,
                                size: 14,
                                color: kWarning,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$missed missed',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: kWarning,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Daily bar chart
            if (days.length >= 2)
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: kDivider),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Daily Adherence',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: kText,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 120,
                        child: BarChart(
                          BarChartData(
                            gridData: const FlGridData(show: false),
                            titlesData: FlTitlesData(
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              leftTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 20,
                                  getTitlesWidget: (v, _) {
                                    final i = v.toInt();
                                    if (i < 0 || i >= days.length) {
                                      return const SizedBox.shrink();
                                    }
                                    return Text(
                                      DateFormat(
                                        'd/M',
                                      ).format(DateTime.parse(days[i].key)),
                                      style: TextStyle(
                                        fontSize: 7,
                                        color: kTextLight,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            barGroups: days.asMap().entries.map((e) {
                              final d = e.value.value;
                              return BarChartGroupData(
                                x: e.key,
                                barRods: [
                                  BarChartRodData(
                                    toY: (d.taken + d.missed).toDouble(),
                                    width: 12,
                                    borderRadius: BorderRadius.circular(4),
                                    rodStackItems: [
                                      BarChartRodStackItem(
                                        0,
                                        d.taken.toDouble(),
                                        kSuccess,
                                      ),
                                      BarChartRodStackItem(
                                        d.taken.toDouble(),
                                        (d.taken + d.missed).toDouble(),
                                        kWarning.withAlpha(100),
                                      ),
                                    ],
                                    color: Colors.transparent,
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 12,
                            height: 8,
                            decoration: BoxDecoration(
                              color: kSuccess,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          Text(
                            ' Taken  ',
                            style: TextStyle(fontSize: 9, color: kTextLight),
                          ),
                          Container(
                            width: 12,
                            height: 8,
                            decoration: BoxDecoration(
                              color: kWarning.withAlpha(100),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          Text(
                            ' Missed',
                            style: TextStyle(fontSize: 9, color: kTextLight),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 60),
          ],
        );
      },
    );
  }
}

class _DayStat {
  int taken = 0;
  int missed = 0;
}
