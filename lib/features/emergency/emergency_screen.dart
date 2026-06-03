import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';
import '../../core/api/api_client.dart';

Future<String?> _fetchTriageNumber() async {
  try {
    final pid = await pApi.patientId;
    if (pid == null) return null;
    final data = await pApi.get('/patient-app/triage/$pid');
    return (data as Map)['triageNumber'] as String?;
  } catch (_) { return null; }
}

/// Emergency contacts — crisis helplines, triage number, and emergency services.
class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(title: const Text('Emergency Help'), backgroundColor: kError.withAlpha(15)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Triage number (set by clinician in desktop)
          FutureBuilder<String?>(
            future: _fetchTriageNumber(),
            builder: (_, snap) {
              final number = snap.data;
              if (number == null || number.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _EmergencyTile(icon: Icons.local_phone, title: 'Triage / Crisis Team',
                  subtitle: 'Your care team crisis number', phone: number, color: kPrimary),
              );
            },
          ),
          // Urgent banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kError.withAlpha(15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kError.withAlpha(40)),
            ),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.emergency, color: kError, size: 24),
                SizedBox(width: 10),
                Expanded(child: Text('If you or someone else is in immediate danger, call 000',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kError))),
              ]),
            ]),
          ),
          const SizedBox(height: 12),

          // Emergency 000
          _EmergencyTile(
            icon: Icons.local_hospital,
            title: 'Emergency Services',
            subtitle: 'Police, Ambulance, Fire',
            phone: '000',
            color: kError,
          ),
          const SizedBox(height: 20),

          // Crisis lines
          const Text('Crisis Helplines', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kText)),
          const SizedBox(height: 10),
          _EmergencyTile(icon: Icons.phone, title: 'Lifeline', subtitle: '24/7 crisis support', phone: '13 11 14', color: kInfo),
          _EmergencyTile(icon: Icons.phone, title: 'Beyond Blue', subtitle: 'Anxiety & depression support', phone: '1300 22 4636', color: const Color(0xFF1565C0)),
          _EmergencyTile(icon: Icons.phone, title: 'Suicide Call Back Service', subtitle: '24/7 professional support', phone: '1300 659 467', color: kPrimary),
          _EmergencyTile(icon: Icons.phone, title: 'Kids Helpline', subtitle: 'For young people 5-25', phone: '1800 55 1800', color: kWarning),
          _EmergencyTile(icon: Icons.phone, title: '13YARN', subtitle: 'Aboriginal & Torres Strait Islander crisis line', phone: '13 92 76', color: const Color(0xFFBF360C)),
          _EmergencyTile(icon: Icons.phone, title: 'MensLine Australia', subtitle: 'Support for men', phone: '1300 78 99 78', color: kMeds),

          const SizedBox(height: 20),
          const Text('Online Support', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kText)),
          const SizedBox(height: 10),
          _LinkTile(title: 'Head to Health', subtitle: 'headtohealth.gov.au', url: 'https://headtohealth.gov.au'),
          _LinkTile(title: 'Beyond Blue Forums', subtitle: 'Online community support', url: 'https://www.beyondblue.org.au/get-support/online-forums'),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _EmergencyTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String phone;
  final Color color;
  const _EmergencyTile({required this.icon, required this.title, required this.subtitle, required this.phone, required this.color});

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _call(phone),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: color.withAlpha(20), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kText)),
            Text(subtitle, style: TextStyle(fontSize: 11, color: kTextLight)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.call, color: Colors.white, size: 14),
              const SizedBox(width: 4),
              Text(phone, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
      ),
    ),
  );

  Future<void> _call(String number) async {
    final uri = Uri.parse('tel:${number.replaceAll(' ', '')}');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}

class _LinkTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String url;
  const _LinkTile({required this.title, required this.subtitle, required this.url});

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading: const Icon(Icons.language, color: kInfo, size: 22),
      title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 11, color: kTextLight)),
      trailing: const Icon(Icons.open_in_new, size: 16, color: kInfo),
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
      },
    ),
  );
}
