import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/api/api_client.dart';

class DigitalCareScreen extends StatefulWidget {
  const DigitalCareScreen({super.key});

  @override
  State<DigitalCareScreen> createState() => _DigitalCareScreenState();
}

class _DigitalCareScreenState extends State<DigitalCareScreen> {
  bool _loading = true;
  String _pathwayId = '';
  String _pathwayName = 'Digital Care Pathway';
  int _lockVersion = 1;
  List<Map<String, dynamic>> _packs = [];
  List<Map<String, dynamic>> _thoughtEntries = [];
  List<Map<String, dynamic>> _sleepEntries = [];
  List<Map<String, dynamic>> _sources = [];
  List<Map<String, dynamic>> _phenotypes = [];
  Map<String, dynamic>? _surveillance;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final patientId = await pApi.patientId;
      if (patientId != null) {
        final interventions = await pApi.get(
          '/patient-app/interventions/$patientId',
        );
        final sources = await pApi.get(
          '/patient-app/wearables/$patientId/sources',
        );
        final phenotypes = await pApi.get(
          '/patient-app/wearables/$patientId/phenotypes',
          params: {'limit': 14},
        );
        final surveillance = await pApi.get(
          '/patient-app/wearables/$patientId/surveillance',
        );
        _pathwayId = (interventions['pathwayId'] ?? '').toString();
        _pathwayName = (interventions['pathwayName'] ?? 'Digital Care Pathway')
            .toString();
        _lockVersion = (interventions['lockVersion'] as num?)?.toInt() ?? 1;
        _packs = ((interventions['packs'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _thoughtEntries =
            ((interventions['thoughtDiaryEntries'] as List?) ?? [])
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
        _sleepEntries = ((interventions['sleepJourneyCheckIns'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _sources = ((sources['sources'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _phenotypes = ((phenotypes['rows'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _surveillance = Map<String, dynamic>.from(
          (surveillance as Map?) ?? const {},
        );
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggleItem(String packId, String itemId, bool completed) async {
    final patientId = await pApi.patientId;
    if (patientId == null) return;
    try {
      await pApi.post(
        '/patient-app/interventions/$patientId/packs/$packId/items/$itemId',
        data: {
          'pathwayId': _pathwayId,
          'expectedLockVersion': _lockVersion,
          'completed': completed,
        },
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update item: $e'),
          backgroundColor: kError,
        ),
      );
    }
  }

  Future<void> _submitThoughtDiary({
    required String situation,
    required String thought,
    required String emotion,
    required int intensity,
    String? balancedThought,
  }) async {
    final patientId = await pApi.patientId;
    if (patientId == null) return;
    await pApi.post(
      '/patient-app/interventions/$patientId/thought-diary',
      data: {
        'pathwayId': _pathwayId,
        'expectedLockVersion': _lockVersion,
        'situation': situation,
        'automaticThought': thought,
        'emotion': emotion,
        'emotionIntensity': intensity,
        if ((balancedThought ?? '').trim().isNotEmpty)
          'balancedThought': balancedThought,
      },
    );
    await _load();
  }

  Future<void> _submitSleepCheckIn({
    required int sleepQuality,
    required double sleepHours,
    required bool caffeineAfterNoon,
    required bool screenAfterBed,
    required bool exerciseDone,
    String? notes,
  }) async {
    final patientId = await pApi.patientId;
    if (patientId == null) return;
    await pApi.post(
      '/patient-app/interventions/$patientId/sleep-hygiene/check-in',
      data: {
        'pathwayId': _pathwayId,
        'expectedLockVersion': _lockVersion,
        'date': DateTime.now().toIso8601String().split('T')[0],
        'sleepHours': sleepHours,
        'sleepQuality': sleepQuality,
        'caffeineAfterNoon': caffeineAfterNoon,
        'screenAfterBed': screenAfterBed,
        'exerciseDone': exerciseDone,
        if ((notes ?? '').trim().isNotEmpty) 'notes': notes,
      },
    );
    await _load();
  }

  Future<void> _createWearableSource({
    required String provider,
    required String deviceLabel,
  }) async {
    final patientId = await pApi.patientId;
    if (patientId == null) return;
    await pApi.post(
      '/patient-app/wearables/$patientId/sources',
      data: {'provider': provider, 'deviceLabel': deviceLabel},
    );
    await _load();
  }

  Future<void> _ingestManualMetric({
    required String sourceId,
    required String metricType,
    required double value,
  }) async {
    final patientId = await pApi.patientId;
    if (patientId == null) return;
    await pApi.post(
      '/patient-app/wearables/$patientId/ingest',
      data: {
        'sourceId': sourceId,
        'entries': [
          {
            'metricType': metricType,
            'value': value,
            'timestamp': DateTime.now().toIso8601String(),
          },
        ],
      },
    );
    await _load();
  }

  void _openThoughtDiaryDialog() {
    final situationCtrl = TextEditingController();
    final thoughtCtrl = TextEditingController();
    final emotionCtrl = TextEditingController();
    final balancedCtrl = TextEditingController();
    double intensity = 60;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Thought Diary Entry',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: situationCtrl,
                  decoration: const InputDecoration(labelText: 'Situation'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: thoughtCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Automatic Thought',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: emotionCtrl,
                  decoration: const InputDecoration(labelText: 'Emotion'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: balancedCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Balanced Thought (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                Text('Intensity: ${intensity.round()}'),
                Slider(
                  value: intensity,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  onChanged: (v) => setSheetState(() => intensity = v),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (situationCtrl.text.trim().isEmpty ||
                        thoughtCtrl.text.trim().isEmpty ||
                        emotionCtrl.text.trim().isEmpty) {
                      return;
                    }
                    Navigator.pop(ctx);
                    await _submitThoughtDiary(
                      situation: situationCtrl.text.trim(),
                      thought: thoughtCtrl.text.trim(),
                      emotion: emotionCtrl.text.trim(),
                      intensity: intensity.round(),
                      balancedThought: balancedCtrl.text.trim(),
                    );
                  },
                  child: const Text('Save Entry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openSleepCheckInDialog() {
    final hoursCtrl = TextEditingController(text: '7');
    final notesCtrl = TextEditingController();
    double quality = 3;
    bool caffeineAfterNoon = false;
    bool screenAfterBed = false;
    bool exerciseDone = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Sleep Hygiene Check-in',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: hoursCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Sleep Hours'),
                ),
                const SizedBox(height: 8),
                Text('Sleep quality: ${quality.round()}/5'),
                Slider(
                  value: quality,
                  min: 1,
                  max: 5,
                  divisions: 4,
                  onChanged: (v) => setSheetState(() => quality = v),
                ),
                CheckboxListTile(
                  value: caffeineAfterNoon,
                  onChanged: (v) =>
                      setSheetState(() => caffeineAfterNoon = v ?? false),
                  title: const Text('Caffeine after noon'),
                  dense: true,
                ),
                CheckboxListTile(
                  value: screenAfterBed,
                  onChanged: (v) =>
                      setSheetState(() => screenAfterBed = v ?? false),
                  title: const Text('Screen use before bed'),
                  dense: true,
                ),
                CheckboxListTile(
                  value: exerciseDone,
                  onChanged: (v) =>
                      setSheetState(() => exerciseDone = v ?? false),
                  title: const Text('Exercise completed today'),
                  dense: true,
                ),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () async {
                    final sleepHours =
                        double.tryParse(hoursCtrl.text.trim()) ?? 0;
                    Navigator.pop(ctx);
                    await _submitSleepCheckIn(
                      sleepQuality: quality.round(),
                      sleepHours: sleepHours,
                      caffeineAfterNoon: caffeineAfterNoon,
                      screenAfterBed: screenAfterBed,
                      exerciseDone: exerciseDone,
                      notes: notesCtrl.text.trim(),
                    );
                  },
                  child: const Text('Save Check-in'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openAddSourceDialog() {
    final labelCtrl = TextEditingController();
    String provider = 'manual_import';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Connect Device Source',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: provider,
                  items: const [
                    DropdownMenuItem(
                      value: 'manual_import',
                      child: Text('Manual Import'),
                    ),
                    DropdownMenuItem(
                      value: 'apple_health',
                      child: Text('Apple Health'),
                    ),
                    DropdownMenuItem(
                      value: 'google_fit',
                      child: Text('Google Fit'),
                    ),
                    DropdownMenuItem(value: 'fitbit', child: Text('Fitbit')),
                    DropdownMenuItem(value: 'garmin', child: Text('Garmin')),
                    DropdownMenuItem(value: 'oura', child: Text('Oura')),
                    DropdownMenuItem(value: 'whoop', child: Text('Whoop')),
                  ],
                  onChanged: (v) =>
                      setSheetState(() => provider = v ?? 'manual_import'),
                  decoration: const InputDecoration(labelText: 'Provider'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: labelCtrl,
                  decoration: const InputDecoration(labelText: 'Device Label'),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () async {
                    if (labelCtrl.text.trim().isEmpty) return;
                    Navigator.pop(ctx);
                    await _createWearableSource(
                      provider: provider,
                      deviceLabel: labelCtrl.text.trim(),
                    );
                  },
                  child: const Text('Add Source'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openManualIngestDialog(Map<String, dynamic> source) {
    final valueCtrl = TextEditingController();
    String metric = 'sleep_hours';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Record Metric — ${source['deviceLabel'] ?? source['provider']}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: metric,
                  items: const [
                    DropdownMenuItem(
                      value: 'sleep_hours',
                      child: Text('Sleep Hours'),
                    ),
                    DropdownMenuItem(value: 'steps', child: Text('Steps')),
                    DropdownMenuItem(
                      value: 'resting_hr',
                      child: Text('Resting HR'),
                    ),
                    DropdownMenuItem(value: 'hrv', child: Text('HRV')),
                    DropdownMenuItem(value: 'mood', child: Text('Mood (0-10)')),
                    DropdownMenuItem(
                      value: 'anxiety',
                      child: Text('Anxiety (0-10)'),
                    ),
                    DropdownMenuItem(
                      value: 'glucose_mgdl',
                      child: Text('Glucose (mg/dL)'),
                    ),
                    DropdownMenuItem(
                      value: 'glucose_mmoll',
                      child: Text('Glucose (mmol/L)'),
                    ),
                    DropdownMenuItem(
                      value: 'cgm_time_in_range_pct',
                      child: Text('CGM Time In Range (%)'),
                    ),
                    DropdownMenuItem(
                      value: 'ecg_afib_flag',
                      child: Text('ECG AFib Flag (0/1)'),
                    ),
                    DropdownMenuItem(
                      value: 'ecg_afib_burden_pct',
                      child: Text('ECG AFib Burden (%)'),
                    ),
                    DropdownMenuItem(
                      value: 'ppg_irregular_rhythm_score',
                      child: Text('PPG Irregular Rhythm Score'),
                    ),
                  ],
                  onChanged: (v) =>
                      setSheetState(() => metric = v ?? 'sleep_hours'),
                  decoration: const InputDecoration(labelText: 'Metric'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: valueCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Value'),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () async {
                    final value = double.tryParse(valueCtrl.text.trim());
                    if (value == null) return;
                    Navigator.pop(ctx);
                    await _ingestManualMetric(
                      sourceId: (source['id'] ?? '').toString(),
                      metricType: metric,
                      value: value,
                    );
                  },
                  child: const Text('Record'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        title: const Text('Digital Care'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: _loading
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'thought',
                  onPressed: _openThoughtDiaryDialog,
                  backgroundColor: const Color(0xFF327C8D),
                  child: const Icon(Icons.psychology, color: Colors.white),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'sleep',
                  onPressed: _openSleepCheckInDialog,
                  backgroundColor: const Color(0xFF2E7D32),
                  child: const Icon(Icons.nights_stay, color: Colors.white),
                ),
              ],
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _pathwayName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: kText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_packs.length} assigned intervention packs · ${_thoughtEntries.length} thought entries · ${_sleepEntries.length} sleep check-ins',
                            style: const TextStyle(
                              fontSize: 12,
                              color: kTextLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Assigned Packs',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: kPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (_packs.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('No packs assigned yet'),
                      ),
                    ),
                  ..._packs.map((pack) {
                    final items = ((pack['items'] as List?) ?? [])
                        .map((e) => Map<String, dynamic>.from(e as Map))
                        .toList();
                    final completed = items
                        .where((i) => i['completed'] == true)
                        .length;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pack['title']?.toString() ?? 'Intervention Pack',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$completed/${items.length} items complete',
                              style: const TextStyle(
                                fontSize: 11,
                                color: kTextLight,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...items.map(
                              (item) => CheckboxListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                value: item['completed'] == true,
                                onChanged: (v) => _toggleItem(
                                  (pack['id'] ?? '').toString(),
                                  (item['id'] ?? '').toString(),
                                  v ?? false,
                                ),
                                title: Text(
                                  item['title']?.toString() ?? '',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  item['description']?.toString() ?? '',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Wearable & Device Sources',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: kPrimary,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _openAddSourceDialog,
                        child: const Text('Add Source'),
                      ),
                    ],
                  ),
                  if (_sources.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('No wearable sources connected'),
                      ),
                    ),
                  ..._sources.map(
                    (source) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          source['deviceLabel']?.toString() ??
                              source['provider']?.toString() ??
                              'Source',
                        ),
                        subtitle: Text(
                          'Provider: ${source['provider'] ?? '-'}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.add_chart),
                          onPressed: () => _openManualIngestDialog(source),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Surveillance Signals (Non-diagnostic)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: kPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        (_surveillance?['disclaimer'] ?? '')
                                .toString()
                                .trim()
                                .isNotEmpty
                            ? _surveillance!['disclaimer'].toString()
                            : 'Signals shown here are surveillance indicators only and must be confirmed by your clinical team.',
                        style: const TextStyle(fontSize: 11, color: kTextLight),
                      ),
                    ),
                  ),
                  ...(((_surveillance?['signals'] as List?) ?? const [])
                      .map((item) => Map<String, dynamic>.from(item as Map))
                      .map(
                        (signal) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${signal['domain'] ?? 'signal'} · score ${signal['score'] ?? 0} (${signal['riskBand'] ?? 'low'})',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  (signal['summary'] ?? '').toString(),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: kTextLight,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Recommended clinician action: ${(signal['recommendedAction'] ?? '').toString()}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: kTextLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList()),
                  const SizedBox(height: 10),
                  const Text(
                    'Digital Phenotype Snapshots',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: kPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (_phenotypes.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('No phenotype snapshots yet'),
                      ),
                    ),
                  ..._phenotypes
                      .take(7)
                      .map(
                        (row) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Date ${row['computationDay'] ?? '-'}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Risk ${row['riskIndex'] ?? 0} (${row['riskBand'] ?? 'low'}) · Adherence ${row['adherenceScore'] ?? 0}%',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: kTextLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            ),
    );
  }
}
