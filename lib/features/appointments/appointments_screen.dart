import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/api/api_client.dart';

/// Appointments & tribunal — with attend/not-attend response (up to 3 days prior).
class AppointmentsScreen extends StatelessWidget {
  const AppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(length: 2, child: Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(title: const Text('Schedule'),
        bottom: const TabBar(tabs: [Tab(text: 'Appointments'), Tab(text: 'Tribunal')])),
      body: const TabBarView(children: [_AppointmentsTab(), _TribunalTab()]),
    ));
  }
}

class _AppointmentsTab extends StatefulWidget {
  const _AppointmentsTab();
  @override
  State<_AppointmentsTab> createState() => _AppointmentsTabState();
}

class _AppointmentsTabState extends State<_AppointmentsTab> {
  List<Map<String, dynamic>> _appts = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final pid = await pApi.patientId;
      if (pid != null) {
        final data = await pApi.get('/patient-app/appointments', params: {'patientId': pid, 'limit': '20'});
        final list = data is List ? data : ((data as Map)['appointments'] ?? data['data'] ?? []) as List;
        _appts = list.map((j) => Map<String, dynamic>.from(j as Map)).toList();
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _respond(String apptId, String response) async {
    try {
      // Use dedicated patient-app endpoint to update response
      await pApi.patch('/patient-app/appointment-response/$apptId', data: {'response': response});
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Response sent: $response'), backgroundColor: kSuccess),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send response'), backgroundColor: kError),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: kPrimary));
    }
    if (_appts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_outlined, size: 48, color: kTextLight.withAlpha(100)),
            const SizedBox(height: 12),
            Text('No upcoming appointments', style: TextStyle(fontSize: 14, color: kTextLight)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: kPrimary,
      onRefresh: () async { setState(() => _loading = true); _load(); },
      child: ListView.builder(
        padding: const EdgeInsets.all(14), itemCount: _appts.length,
        itemBuilder: (_, i) => _ApptCard(appt: _appts[i], onRespond: _respond),
      ),
    );
  }
}

class _ApptCard extends StatelessWidget {
  final Map<String, dynamic> appt;
  final Future<void> Function(String id, String response) onRespond;
  const _ApptCard({required this.appt, required this.onRespond});

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.tryParse(appt['startTime'] ?? appt['appointmentDate'] ?? appt['createdAt'] ?? '');
    final dateStr = dt != null ? '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}' : '';
    final status = (appt['status'] ?? '').toString();
    final patientResponse = appt['patientResponse'] as String?;
    final id = appt['id']?.toString() ?? '';

    // Can respond up to 3 days before
    final canRespond = dt != null && dt.difference(DateTime.now()).inDays <= 3 && dt.isAfter(DateTime.now()) && patientResponse == null;

    final statusColor = status == 'confirmed' ? kSuccess : status == 'cancelled' ? kError : kWarning;

    return Card(margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: kDivider)),
      child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: kWarning.withAlpha(20), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.event, color: kWarning, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(appt['title'] ?? appt['appointmentType'] ?? 'Appointment', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kText)),
            Text(dateStr, style: TextStyle(fontSize: 12, color: kTextLight)),
            if (appt['clinicianName'] != null) Text('With: ${appt['clinicianName']}', style: TextStyle(fontSize: 11, color: kTextLight)),
            if (appt['location'] != null) Text(appt['location'].toString(), style: TextStyle(fontSize: 11, color: kTextLight)),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: statusColor.withAlpha(20), borderRadius: BorderRadius.circular(6)),
            child: Text(status.isEmpty ? 'Scheduled' : status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor))),
        ]),

        // Response buttons
        if (patientResponse != null) Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(children: [
            Icon(patientResponse == 'attending' ? Icons.check_circle : Icons.cancel,
              size: 16, color: patientResponse == 'attending' ? kSuccess : kError),
            const SizedBox(width: 6),
            Text(patientResponse == 'attending' ? 'You confirmed: Attending' : 'You responded: Not Attending',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: patientResponse == 'attending' ? kSuccess : kError)),
          ]),
        )
        else if (canRespond) Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(children: [
            Expanded(child: ElevatedButton.icon(
              onPressed: () => onRespond(id, 'attending'),
              icon: const Icon(Icons.check, color: Colors.white, size: 16),
              label: const Text('Attending', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(backgroundColor: kSuccess, minimumSize: const Size(0, 36)),
            )),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(
              onPressed: () => onRespond(id, 'not_attending'),
              icon: const Icon(Icons.close, size: 16),
              label: const Text('Not Attending', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(foregroundColor: kError, side: const BorderSide(color: kError), minimumSize: const Size(0, 36)),
            )),
          ]),
        )
        else if (dt != null && dt.isAfter(DateTime.now())) Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('You can respond ${3 - dt.difference(DateTime.now()).inDays} days before the appointment',
            style: TextStyle(fontSize: 10, color: kTextLight)),
        ),

        // Pre-appointment checklist
        _ChecklistSection(appointmentId: id),
      ])),
    );
  }
}

class _ChecklistSection extends StatefulWidget {
  final String appointmentId;
  const _ChecklistSection({required this.appointmentId});
  @override
  State<_ChecklistSection> createState() => _ChecklistSectionState();
}

class _ChecklistSectionState extends State<_ChecklistSection> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final pid = await pApi.patientId;
      if (pid != null) {
        final data = await pApi.get('/patient-app/checklists/$pid', params: {'appointmentId': widget.appointmentId});
        _items = ((data as Map)['checklists'] as List? ?? []).map((j) => Map<String, dynamic>.from(j as Map)).toList();
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _toggle(String itemId, bool value) async {
    try {
      final pid = await pApi.patientId;
      await pApi.patch('/patient-app/checklists/$pid/$itemId', data: {'isCompleted': value});
      _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(8)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.checklist, size: 14, color: kPrimary),
            const SizedBox(width: 4),
            const Text('Pre-Appointment Checklist', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kText)),
          ]),
          const SizedBox(height: 6),
          ..._items.map((item) {
            final done = item['isCompleted'] == true || item['is_completed'] == true;
            return InkWell(
              onTap: () => _toggle(item['id']?.toString() ?? '', !done),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Icon(done ? Icons.check_box : Icons.check_box_outline_blank, size: 18, color: done ? kSuccess : kTextLight),
                  const SizedBox(width: 6),
                  Expanded(child: Text(item['item'] ?? '', style: TextStyle(fontSize: 11,
                    color: done ? kTextLight : kText, decoration: done ? TextDecoration.lineThrough : null))),
                ]),
              ),
            );
          }),
        ]),
      ),
    );
  }
}

class _TribunalTab extends StatefulWidget {
  const _TribunalTab();
  @override
  State<_TribunalTab> createState() => _TribunalTabState();
}

class _TribunalTabState extends State<_TribunalTab> {
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final pid = await pApi.patientId;
      if (pid != null) {
        final data = await pApi.get('/patient-app/legal-orders/$pid');
        final list = data is List ? data : ((data as Map)['orders'] ?? data['data'] ?? []) as List;
        _orders = list.map((j) => Map<String, dynamic>.from(j as Map)).toList();
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: kPrimary));
    }
    if (_orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.gavel_outlined, size: 48, color: kTextLight.withAlpha(100)),
            const SizedBox(height: 12),
            Text('No tribunal hearings', style: TextStyle(fontSize: 14, color: kTextLight)),
          ],
        ),
      );
    }
    return ListView.builder(padding: const EdgeInsets.all(14), itemCount: _orders.length,
      itemBuilder: (_, i) {
        final o = _orders[i];
        return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
          leading: const Icon(Icons.gavel, color: kInfo, size: 22),
          title: Text(o['orderType'] ?? o['type'] ?? 'Legal Order', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: Text('${o['hearingDate'] ?? o['startDate'] ?? ''}\n${o['status'] ?? ''}', style: TextStyle(fontSize: 12, color: kTextLight)),
        ));
      });
  }
}
