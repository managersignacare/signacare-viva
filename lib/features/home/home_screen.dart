import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/services/auth_service.dart';
import '../../core/api/api_client.dart';
import '../tracking/tracking_screen.dart';
import '../vitals/vitals_screen.dart';
import '../documents/documents_screen.dart';
import '../appointments/appointments_screen.dart';
import '../messaging/messaging_screen.dart';
import '../reminders/reminders_screen.dart';
import '../rating_scales/rating_scales_screen.dart';
import '../emergency/emergency_screen.dart';
import '../profile/profile_screen.dart';
import '../diary/diary_screen.dart';
import '../recovery/recovery_goals_screen.dart';
import '../activity/activity_schedule_screen.dart';
import '../mindfulness/mindfulness_screen.dart';
import '../sync/sync_settings_screen.dart';
import '../patient_tasks/patient_tasks_screen.dart';
import '../digital_care/digital_care_screen.dart';

class PatientHomeScreen extends ConsumerStatefulWidget {
  const PatientHomeScreen({super.key});
  @override
  ConsumerState<PatientHomeScreen> createState() => _PatientHomeState();
}

class _PatientHomeState extends ConsumerState<PatientHomeScreen> {
  int _tab = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  static const _navItems = [
    ('Home', Icons.home_outlined, Icons.home),
    ('Track', Icons.track_changes_outlined, Icons.track_changes),
    ('Messages', Icons.message_outlined, Icons.message),
    ('Profile', Icons.person_outline, Icons.person),
  ];

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(patientAuthProvider).user;
    final pages = [
      _DashboardPage(scaffoldKey: _scaffoldKey),
      const TrackingScreen(),
      const MessagingScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      key: _scaffoldKey,
      drawer: _AppDrawer(
        userName: user?.displayName ?? 'Patient',
        onNavigate: (screen) {
          Navigator.pop(context); // close drawer
          Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
        },
      ),
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        items: _navItems.map((n) => BottomNavigationBarItem(
          icon: Icon(n.$2), activeIcon: Icon(n.$3), label: n.$1,
        )).toList(),
      ),
    );
  }
}

// ── Auto-hiding Sidebar Drawer ──

class _AppDrawer extends StatelessWidget {
  final String userName;
  final void Function(Widget screen) onNavigate;
  const _AppDrawer({required this.userName, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final items = [
      _DrawerItem(Icons.self_improvement, 'Daily Check-in', kMood, const TrackingScreen()),
      _DrawerItem(Icons.monitor_heart_outlined, 'Vitals', kError, const VitalsScreen()),
      _DrawerItem(Icons.task_alt, 'My Tasks', kWarning, const PatientTasksScreen()),
      _DrawerItem(Icons.psychology_alt_outlined, 'Digital Care', kPrimary, const DigitalCareScreen()),
      _DrawerItem(Icons.medication_outlined, 'Medications', kMeds, const RemindersScreen()),
      _DrawerItem(Icons.description_outlined, 'Documents & Records', kInfo, const DocumentsScreen()),
      _DrawerItem(Icons.calendar_today_outlined, 'Appointments', kWarning, const AppointmentsScreen()),
      _DrawerItem(Icons.message_outlined, 'Messages', kPrimary, const MessagingScreen()),
      _DrawerItem(Icons.book_outlined, 'My Diary', const Color(0xFF5C6BC0), const DiaryScreen()),
      _DrawerItem(Icons.flag_outlined, 'Recovery Goals', kSuccess, const RecoveryGoalsScreen()),
      _DrawerItem(Icons.schedule_outlined, 'Activity Schedule', kWarning, const ActivityScheduleScreen()),
      _DrawerItem(Icons.self_improvement, 'Mindfulness', const Color(0xFF00897B), const MindfulnessScreen()),
      _DrawerItem(Icons.assessment_outlined, 'Assessments', const Color(0xFF6A1B9A), const RatingScalesScreen()),
      _DrawerItem(Icons.sync, 'Sync Settings', const Color(0xFF00897B), const SyncSettingsScreen()),
      _DrawerItem(Icons.emergency_outlined, 'Emergency Help', kError, const EmergencyScreen()),
      _DrawerItem(Icons.person_outline, 'My Profile', kTextLight, const ProfileScreen()),
    ];

    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: BoxDecoration(
              color: kPrimary.withAlpha(10),
              border: Border(bottom: BorderSide(color: kDivider)),
            ),
            child: Row(children: [
              SvgPicture.asset('assets/signacare-logo.svg', width: 28, height: 28,
                colorFilter: const ColorFilter.mode(kPrimary, BlendMode.srcIn)),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Viva', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kPrimary)),
                Text(userName, style: const TextStyle(fontSize: 12, color: kTextLight)),
              ]),
            ]),
          ),
          // Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: items.map((item) => ListTile(
                leading: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(color: item.color.withAlpha(20), borderRadius: BorderRadius.circular(8)),
                  child: Icon(item.icon, color: item.color, size: 18),
                ),
                title: Text(item.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: kText)),
                dense: true,
                onTap: () => onNavigate(item.screen),
              )).toList(),
            ),
          ),
        ]),
      ),
    );
  }
}

class _DrawerItem {
  final IconData icon;
  final String label;
  final Color color;
  final Widget screen;
  const _DrawerItem(this.icon, this.label, this.color, this.screen);
}

// ── Dashboard Page ──

class _DashboardPage extends ConsumerWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;
  const _DashboardPage({required this.scaffoldKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(patientAuthProvider).user;
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, d MMMM yyyy').format(now);
    final greeting = _greeting();

    return Scaffold(
      backgroundColor: kSurface,
      body: CustomScrollView(
        slivers: [
          // ── Header with date + hamburger ──
          SliverAppBar(
            expandedHeight: 120, pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.menu, color: kText),
              onPressed: () => scaffoldKey.currentState?.openDrawer(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.symmetric(horizontal: 56, vertical: 12),
              title: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  SvgPicture.asset('assets/signacare-logo.svg', width: 16, height: 16,
                    colorFilter: const ColorFilter.mode(kPrimary, BlendMode.srcIn)),
                  const SizedBox(width: 6),
                  const Text('Viva', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kPrimary)),
                ]),
                Text('$greeting, ${user?.givenName ?? 'there'}',
                  style: const TextStyle(fontSize: 11, color: kTextLight, fontWeight: FontWeight.w400),
                  overflow: TextOverflow.ellipsis),
                Text(dateStr, style: const TextStyle(fontSize: 9, color: kTextLight, fontWeight: FontWeight.w400)),
              ]),
            ),
          ),

          // ── Content ──
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
            sliver: SliverList(delegate: SliverChildListDelegate([
              // ── Check-in prompt ──
              _CompactCard(icon: Icons.self_improvement, color: kMood,
                title: 'How are you today?', subtitle: 'Log mood, anxiety, sleep & energy',
                onTap: () => _push(context, const TrackingScreen())),
              const SizedBox(height: 14),

              // ── MY WELLBEING (patient-initiated) ──
              _SectionLabel('My Wellbeing', Icons.favorite_outline, kPrimary),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: _MiniCard(icon: Icons.monitor_heart, color: kError, label: 'Vitals',
                  onTap: () => _push(context, const VitalsScreen()))),
                const SizedBox(width: 8),
                Expanded(child: _MiniCard(icon: Icons.book, color: const Color(0xFF5C6BC0), label: 'My Diary',
                  onTap: () => _push(context, const DiaryScreen()))),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _MiniCard(icon: Icons.flag, color: kSuccess, label: 'Recovery Goals',
                  onTap: () => _push(context, const RecoveryGoalsScreen()))),
                const SizedBox(width: 8),
                Expanded(child: _MiniCard(icon: Icons.schedule, color: kWarning, label: 'Activity Schedule',
                  onTap: () => _push(context, const ActivityScheduleScreen()))),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _MiniCard(icon: Icons.self_improvement, color: const Color(0xFF00897B), label: 'Mindfulness',
                  onTap: () => _push(context, const MindfulnessScreen()))),
                const SizedBox(width: 8),
                Expanded(child: _MiniCard(icon: Icons.person, color: kTextLight, label: 'My Profile',
                  onTap: () => _push(context, const ProfileScreen()))),
              ]),
              const SizedBox(height: 14),

              // ── FROM MY CARE TEAM (clinician-shared) ──
              _SectionLabel('From My Care Team', Icons.local_hospital_outlined, kInfo),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: _MiniCard(icon: Icons.groups, color: kInfo, label: 'My MDT',
                  onTap: () => _push(context, const _MdtScreen()))),
                const SizedBox(width: 8),
                Expanded(child: _MiniCard(icon: Icons.task_alt, color: kWarning, label: 'My Tasks',
                  onTap: () => _push(context, const PatientTasksScreen()))),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _MiniCard(icon: Icons.psychology_alt, color: kPrimary, label: 'Digital Care',
                  onTap: () => _push(context, const DigitalCareScreen()))),
                const SizedBox(width: 8),
                const Expanded(child: SizedBox.shrink()),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _MiniCard(icon: Icons.medication, color: kMeds, label: 'Medications',
                  onTap: () => _push(context, const RemindersScreen()))),
                const SizedBox(width: 8),
                Expanded(child: _MiniCard(icon: Icons.description, color: kInfo, label: 'Documents',
                  onTap: () => _push(context, const DocumentsScreen()))),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _MiniCard(icon: Icons.calendar_today, color: kWarning, label: 'Appointments',
                  onTap: () => _push(context, const AppointmentsScreen()))),
                const SizedBox(width: 8),
                Expanded(child: _MiniCard(icon: Icons.message, color: kPrimary, label: 'Messages',
                  onTap: () => _push(context, const MessagingScreen()))),
                const SizedBox(width: 8),
                Expanded(child: _MiniCard(icon: Icons.assessment, color: const Color(0xFF6A1B9A), label: 'Assessments',
                  onTap: () => _push(context, const RatingScalesScreen()))),
              ]),
              const SizedBox(height: 14),

              // ── Emergency ──
              _CompactCard(icon: Icons.emergency, color: kError,
                title: 'Need Help Now?', subtitle: 'Crisis helplines & emergency',
                onTap: () => _push(context, const EmergencyScreen()), outlined: true),
            ])),
          ),
        ],
      ),
    );
  }

  void _push(BuildContext context, Widget screen) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

// ── Section Label ──

class _SectionLabel extends StatelessWidget {
  final String text; final IconData icon; final Color color;
  const _SectionLabel(this.text, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 14, color: color),
    const SizedBox(width: 6),
    Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.3)),
  ]);
}

// ── Compact Card (full width, small height) ──

class _CompactCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool outlined;
  const _CompactCard({required this.icon, required this.color, required this.title,
    required this.subtitle, required this.onTap, this.outlined = false});

  @override
  Widget build(BuildContext context) => Material(
    color: outlined ? color.withAlpha(10) : Colors.white,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: outlined ? color.withAlpha(40) : kDivider),
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: outlined ? color : kText)),
            Text(subtitle, style: TextStyle(fontSize: 10, color: kTextLight)),
          ])),
          Icon(Icons.chevron_right, size: 18, color: outlined ? color : kTextLight),
        ]),
      ),
    ),
  );
}

// ── Mini Card (half width, compact) ──

class _MiniCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  const _MiniCard({required this.icon, required this.color, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kDivider),
        ),
        child: Row(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(color: color.withAlpha(18), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 8),
          Flexible(child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kText),
            overflow: TextOverflow.ellipsis)),
        ]),
      ),
    ),
  );
}

// ── My MDT Screen — shows care team from current episode ──

class _MdtScreen extends StatelessWidget {
  const _MdtScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(title: const Text('My Care Team')),
      body: FutureBuilder(
        future: _fetchMdt(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kPrimary));
          }
          final mdt = snap.data ?? [];
          if (mdt.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.groups_outlined, size: 48, color: kTextLight.withAlpha(100)),
                  const SizedBox(height: 12),
                  const Text(
                    'No team assigned yet',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kText),
                  ),
                  Text(
                    'Your care team will appear here once assigned',
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: kInfo.withAlpha(10), borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Icons.info_outline, size: 16, color: kInfo),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Your multidisciplinary team (MDT) from your current episode',
                    style: TextStyle(fontSize: 11, color: kTextLight))),
                ]),
              ),
              const SizedBox(height: 14),
              ...mdt.map((m) {
                final member = Map<String, dynamic>.from(m as Map);
                final name = member['staffName'] ?? member['name'] ?? 'Team Member';
                final role = member['roleName'] ?? member['role'] ?? '';
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: kDivider)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      CircleAvatar(radius: 20, backgroundColor: kPrimary.withAlpha(20),
                        child: Text(name.toString().isNotEmpty ? name.toString()[0] : '?',
                          style: const TextStyle(color: kPrimary, fontWeight: FontWeight.w700))),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(name.toString(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kText)),
                        if (role.toString().isNotEmpty) Text(role.toString(),
                          style: TextStyle(fontSize: 12, color: kPrimary, fontWeight: FontWeight.w500)),
                      ])),
                    ]),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Future<List> _fetchMdt() async {
    try {
      final pid = await pApi.patientId;
      if (pid == null) return [];
      // Get current episode
      final epData = await pApi.get('/patient-app/episodes/$pid');
      final episodes = ((epData as Map)['data'] as List?) ?? [];
      final open = episodes.where((e) => (e as Map)['status'] == 'open').toList();
      if (open.isEmpty) return [];
      final episodeId = (open.first as Map)['id'];
      // Get allocation (MDT) for this episode
      final allocData = await pApi.get('/patient-app/episodes/$episodeId/allocation');
      final mdt = (allocData as Map)['mdt'] as List? ?? [];
      return mdt;
    } catch (_) { return []; }
  }
}
