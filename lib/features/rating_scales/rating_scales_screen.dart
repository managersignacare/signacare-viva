import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/api/api_client.dart';

/// Assessments — rating scales shared by clinicians for patient to complete.
class RatingScalesScreen extends StatelessWidget {
  const RatingScalesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: kSurface,
        appBar: AppBar(
          title: const Text('Assessments'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'To Complete'),
              Tab(text: 'Completed'),
            ],
          ),
        ),
        body: const TabBarView(children: [_PendingTab(), _CompletedTab()]),
      ),
    );
  }
}

class _PendingTab extends StatelessWidget {
  const _PendingTab();

  Future<List<Map<String, dynamic>>> _fetch() async {
    try {
      final pid = await pApi.patientId;
      if (pid == null) return [];
      final data = await pApi.get('/patient-app/assessments/$pid');
      final list = (data as Map)['assessments'] as List? ?? [];
      return list
          .map((j) => Map<String, dynamic>.from(j as Map))
          .where(
            (m) =>
                m['status'] == 'pending' ||
                m['status'] == 'sent' ||
                m['status'] == null,
          )
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
        final scales = snap.data ?? [];
        if (scales.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.assignment_outlined,
                  size: 48,
                  color: kTextLight.withAlpha(100),
                ),
                const SizedBox(height: 12),
                const Text(
                  'No assessments to complete',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: kText,
                  ),
                ),
                Text(
                  'Your clinician will share assessments when needed',
                  style: TextStyle(fontSize: 12, color: kTextLight),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: scales.length,
          itemBuilder: (_, i) => _ScaleCard(scale: scales[i], isPending: true),
        );
      },
    );
  }
}

class _CompletedTab extends StatelessWidget {
  const _CompletedTab();

  Future<List<Map<String, dynamic>>> _fetch() async {
    try {
      final pid = await pApi.patientId;
      if (pid == null) return [];
      final data = await pApi.get('/patient-app/assessments/$pid');
      final list = (data as Map)['assessments'] as List? ?? [];
      return list
          .map((j) => Map<String, dynamic>.from(j as Map))
          .where((m) => m['status'] == 'completed')
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
        final scales = snap.data ?? [];
        if (scales.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 48,
                  color: kTextLight.withAlpha(100),
                ),
                const SizedBox(height: 12),
                Text(
                  'No completed assessments',
                  style: TextStyle(fontSize: 14, color: kTextLight),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: scales.length,
          itemBuilder: (_, i) => _ScaleCard(scale: scales[i], isPending: false),
        );
      },
    );
  }
}

class _ScaleCard extends StatelessWidget {
  final Map<String, dynamic> scale;
  final bool isPending;
  const _ScaleCard({required this.scale, required this.isPending});

  @override
  Widget build(BuildContext context) {
    final name =
        scale['templateName'] ??
        scale['scaleName'] ??
        scale['name'] ??
        'Assessment';
    final assignedBy = scale['assignedBy'] ?? scale['clinicianName'] ?? '';
    final score = scale['totalScore'];
    final completedAt = scale['completedAt'];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: kDivider),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: isPending
            ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _CompleteScaleScreen(scale: scale),
                ),
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: (isPending ? kWarning : kSuccess).withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isPending ? Icons.assignment : Icons.assignment_turned_in,
                  color: isPending ? kWarning : kSuccess,
                  size: 22,
                ),
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
                    if (assignedBy.toString().isNotEmpty)
                      Text(
                        'From: $assignedBy',
                        style: TextStyle(fontSize: 11, color: kTextLight),
                      ),
                    if (!isPending && score != null)
                      Text(
                        'Score: $score',
                        style: TextStyle(
                          fontSize: 11,
                          color: kSuccess,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (!isPending && completedAt != null)
                      Text(
                        'Completed: ${_formatDate(completedAt)}',
                        style: TextStyle(fontSize: 10, color: kTextLight),
                      ),
                  ],
                ),
              ),
              if (isPending) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: kPrimary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Start',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(dynamic d) {
    final dt = DateTime.tryParse(d.toString());
    if (dt == null) return '';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _CompleteScaleScreen extends StatefulWidget {
  final Map<String, dynamic> scale;
  const _CompleteScaleScreen({required this.scale});
  @override
  State<_CompleteScaleScreen> createState() => _CompleteScaleState();
}

class _CompleteScaleState extends State<_CompleteScaleScreen> {
  final Map<int, int> _answers = {};
  bool _submitting = false;

  List<String> get _questions {
    final items = widget.scale['items'] as List?;
    if (items != null && items.isNotEmpty) {
      return items.map((i) {
        final item = i as Map;
        return item['question']?.toString() ??
            item['label']?.toString() ??
            'Question';
      }).toList();
    }
    return [
      'In the past 4 weeks, how often did you feel tired for no good reason?',
      'In the past 4 weeks, how often did you feel nervous?',
      'In the past 4 weeks, how often did you feel so nervous that nothing could calm you down?',
      'In the past 4 weeks, how often did you feel hopeless?',
      'In the past 4 weeks, how often did you feel restless or fidgety?',
      'In the past 4 weeks, how often did you feel so restless you could not sit still?',
      'In the past 4 weeks, how often did you feel depressed?',
      'In the past 4 weeks, how often did you feel that everything was an effort?',
      'In the past 4 weeks, how often did you feel so sad that nothing could cheer you up?',
      'In the past 4 weeks, how often did you feel worthless?',
    ];
  }

  List<String> get _options {
    final items = widget.scale['items'] as List?;
    if (items != null && items.isNotEmpty) {
      final first = items.first as Map;
      final opts = first['options'] as List?;
      if (opts != null && opts.isNotEmpty) {
        return opts.map((o) => o.toString()).toList();
      }
    }
    return [
      'None of the time',
      'A little',
      'Some of the time',
      'Most of the time',
      'All of the time',
    ];
  }

  Future<void> _submit() async {
    if (_answers.length < _questions.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please answer all questions'),
          backgroundColor: kWarning,
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final totalScore = _answers.values.fold(0, (sum, v) => sum + v);
      final scaleId = widget.scale['id'];
      final pid = await pApi.patientId;
      if (scaleId != null && pid != null) {
        await pApi.patch(
          '/patient-app/assessments/$pid/$scaleId/complete',
          data: {
            'totalScore': totalScore,
            'responses': _answers.map((k, v) => MapEntry(k.toString(), v)),
          },
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Score: $totalScore — sent to your clinician'),
            backgroundColor: kSuccess,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: kError),
        );
      }
    }
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final name =
        widget.scale['templateName'] ?? widget.scale['name'] ?? 'Assessment';
    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        title: Text(name.toString(), style: const TextStyle(fontSize: 15)),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: _answers.length / _questions.length.clamp(1, 100),
            backgroundColor: kDivider,
            color: kPrimary,
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: _questions.length + 1,
              itemBuilder: (_, i) {
                if (i == _questions.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Submit (Score: ${_answers.values.fold(0, (s, v) => s + v)})',
                            ),
                    ),
                  );
                }
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: kDivider),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Q${i + 1}. ${_questions[i]}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: kText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...List.generate(_options.length, (oi) {
                          final answerValue = oi + 1;
                          final selected = _answers[i] == answerValue;
                          return InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () =>
                                setState(() => _answers[i] = answerValue),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    selected
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_unchecked,
                                    color: selected ? kPrimary : kTextLight,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${oi + 1}. ${_options[oi]}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
