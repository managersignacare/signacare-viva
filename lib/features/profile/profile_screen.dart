import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../core/theme.dart';
import '../../core/services/auth_service.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileState();
}

class _ProfileState extends ConsumerState<ProfileScreen> {
  Map<String, dynamic> _profile = {};
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('viva_profile') ?? '{}';
    _profile = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    // Merge with user data
    final user = ref.read(patientAuthProvider).user;
    if (user != null) {
      _profile['givenName'] ??= user.givenName;
      _profile['familyName'] ??= user.familyName;
      _profile['phone'] ??= user.phone;
      _profile['email'] ??= user.email;
    }
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('viva_profile', jsonEncode(_profile));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved'), backgroundColor: kSuccess, duration: Duration(seconds: 1)),
      );
    }
  }

  void _editSection(String title, List<_Field> fields) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _EditSheet(title: title, fields: fields, profile: _profile, onSaved: (updated) {
        setState(() => _profile = {..._profile, ...updated});
        _save();
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(patientAuthProvider).user;

    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: kPrimary)));

    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(title: const Text('My Profile')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // Avatar
          Center(child: Column(children: [
            CircleAvatar(radius: 36, backgroundColor: kPrimary,
              child: Text('${(user?.givenName ?? '?')[0]}${(user?.familyName ?? '')[0]}',
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700))),
            const SizedBox(height: 10),
            Text(user?.displayName ?? 'Patient', style: VivaText.heading),
          ])),
          const SizedBox(height: 20),

          _ProfileSection(title: 'My Details', icon: Icons.person_outline, color: kPrimary, fields: [
            _DisplayRow('First Name', _profile['givenName']),
            _DisplayRow('Last Name', _profile['familyName']),
            _DisplayRow('Phone', _profile['phone']),
            _DisplayRow('Email', _profile['email']),
            _DisplayRow('Date of Birth', _profile['dob']),
            _DisplayRow('Address', _profile['address']),
          ], onEdit: () => _editSection('My Details', [
            _Field('givenName', 'First Name'), _Field('familyName', 'Last Name'),
            _Field('phone', 'Phone', type: TextInputType.phone), _Field('email', 'Email', type: TextInputType.emailAddress),
            _Field('dob', 'Date of Birth'), _Field('address', 'Address'),
          ])),

          _ProfileSection(title: 'Next of Kin', icon: Icons.family_restroom, color: const Color(0xFFE91E63), fields: [
            _DisplayRow('Name', _profile['nokName']),
            _DisplayRow('Relationship', _profile['nokRelationship']),
            _DisplayRow('Phone', _profile['nokPhone']),
            _DisplayRow('Email', _profile['nokEmail']),
          ], onEdit: () => _editSection('Next of Kin', [
            _Field('nokName', 'Name'), _Field('nokRelationship', 'Relationship'),
            _Field('nokPhone', 'Phone', type: TextInputType.phone), _Field('nokEmail', 'Email', type: TextInputType.emailAddress),
          ])),
          _ConsentCard(
            label: 'Next of Kin',
            consentKey: 'nokConsent',
            detailsKey: 'nokConsentDetails',
            profile: _profile,
            onChanged: (key, value) { setState(() => _profile[key] = value); _save(); },
          ),

          _ProfileSection(title: 'Support Person / Carer', icon: Icons.favorite_outline, color: kSuccess, fields: [
            _DisplayRow('Name', _profile['supportName']),
            _DisplayRow('Relationship', _profile['supportRelationship']),
            _DisplayRow('Phone', _profile['supportPhone']),
            _DisplayRow('Email', _profile['supportEmail']),
          ], onEdit: () => _editSection('Support Person', [
            _Field('supportName', 'Name'), _Field('supportRelationship', 'Relationship'),
            _Field('supportPhone', 'Phone', type: TextInputType.phone), _Field('supportEmail', 'Email', type: TextInputType.emailAddress),
          ])),
          _ConsentCard(
            label: 'Support Person / Carer',
            consentKey: 'supportConsent',
            detailsKey: 'supportConsentDetails',
            profile: _profile,
            onChanged: (key, value) { setState(() => _profile[key] = value); _save(); },
          ),

          _ProfileSection(title: 'GP / Doctor', icon: Icons.local_hospital_outlined, color: kInfo, fields: [
            _DisplayRow('Name', _profile['gpName']),
            _DisplayRow('Practice', _profile['gpPractice']),
            _DisplayRow('Phone', _profile['gpPhone']),
            _DisplayRow('Email', _profile['gpEmail']),
          ], onEdit: () => _editSection('GP / Doctor', [
            _Field('gpName', 'Doctor Name'), _Field('gpPractice', 'Practice Name'),
            _Field('gpPhone', 'Phone', type: TextInputType.phone), _Field('gpEmail', 'Email', type: TextInputType.emailAddress),
          ])),

          _ProfileSection(title: 'Other Providers', icon: Icons.medical_services_outlined, color: kWarning, fields: [
            _DisplayRow('Name', _profile['providerName']),
            _DisplayRow('Specialty', _profile['providerSpecialty']),
            _DisplayRow('Phone', _profile['providerPhone']),
          ], onEdit: () => _editSection('Other Providers', [
            _Field('providerName', 'Provider Name'), _Field('providerSpecialty', 'Specialty'),
            _Field('providerPhone', 'Phone', type: TextInputType.phone),
          ])),

          _ProfileSection(title: 'Allergies & Adverse Reactions', icon: Icons.warning_amber_rounded, color: kError, fields: [
            _DisplayRow('Drug Allergies', _profile['drugAllergies']),
            _DisplayRow('Food Allergies', _profile['foodAllergies']),
            _DisplayRow('Other Allergies', _profile['otherAllergies']),
            _DisplayRow('Adverse Reactions', _profile['adverseReactions']),
          ], onEdit: () => _editSection('Allergies & Adverse Reactions', [
            _Field('drugAllergies', 'Drug Allergies (e.g. Penicillin, Sulfa)'),
            _Field('foodAllergies', 'Food Allergies (e.g. Nuts, Shellfish)'),
            _Field('otherAllergies', 'Other Allergies (e.g. Latex, Bee stings)'),
            _Field('adverseReactions', 'Adverse Reactions to Medications'),
          ])),

          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () async {
              await ref.read(patientAuthProvider.notifier).logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const PatientLoginScreen()),
                  (_) => false,
                );
              }
            },
            icon: const Icon(Icons.logout, color: Colors.white),
            label: const Text('Sign Out'),
            style: ElevatedButton.styleFrom(backgroundColor: kError),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _DisplayRow extends StatelessWidget {
  final String label; final String? value;
  const _DisplayRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(children: [
      SizedBox(width: 90, child: Text(label, style: TextStyle(fontSize: 11, color: kTextLight))),
      Expanded(child: Text(value?.isNotEmpty == true ? value! : '—', style: const TextStyle(fontSize: 12, color: kText))),
    ]),
  );
}

class _ProfileSection extends StatelessWidget {
  final String title; final IconData icon; final Color color;
  final List<Widget> fields; final VoidCallback onEdit;
  const _ProfileSection({required this.title, required this.icon, required this.color,
    required this.fields, required this.onEdit});

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: kDivider)),
    child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 28, height: 28, decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(7)),
          child: Icon(icon, color: color, size: 16)),
        const SizedBox(width: 8),
        Expanded(child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color))),
        IconButton(icon: const Icon(Icons.edit, size: 16, color: kTextLight), onPressed: onEdit, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
      ]),
      const SizedBox(height: 8),
      ...fields,
    ])),
  );
}

class _Field { final String key, label; final TextInputType type; const _Field(this.key, this.label, {this.type = TextInputType.text}); }

class _EditSheet extends StatefulWidget {
  final String title; final List<_Field> fields; final Map<String, dynamic> profile;
  final void Function(Map<String, dynamic>) onSaved;
  const _EditSheet({required this.title, required this.fields, required this.profile, required this.onSaved});
  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final Map<String, TextEditingController> _ctrls;

  @override
  void initState() {
    super.initState();
    _ctrls = { for (final f in widget.fields) f.key: TextEditingController(text: widget.profile[f.key]?.toString() ?? '') };
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(widget.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: kText)),
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        ]),
        const Divider(),
        ...widget.fields.map((f) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextField(controller: _ctrls[f.key], keyboardType: f.type, decoration: InputDecoration(labelText: f.label)),
        )),
        const SizedBox(height: 8),
        ElevatedButton(onPressed: () {
          final data = { for (final f in widget.fields) f.key: _ctrls[f.key]!.text.trim() };
          widget.onSaved(data);
          Navigator.pop(context);
        }, child: const Text('Save')),
      ])),
    );
  }
}

// ── Consent Card — information sharing preferences per contact ──

class _ConsentCard extends StatefulWidget {
  final String label;
  final String consentKey;
  final String detailsKey;
  final Map<String, dynamic> profile;
  final void Function(String key, String value) onChanged;
  const _ConsentCard({required this.label, required this.consentKey, required this.detailsKey,
    required this.profile, required this.onChanged});
  @override
  State<_ConsentCard> createState() => _ConsentCardState();
}

class _ConsentCardState extends State<_ConsentCard> {
  late String _consent;
  late final TextEditingController _detailsCtrl;
  bool _showDetails = false;

  static const List<(String, String, String, IconData, Color)> _options = [
    ('emergency_only', 'Emergency Only', 'Share information only in medical emergencies', Icons.emergency, kWarning),
    ('full', 'Full Consent', 'Share all health information with this person', Icons.check_circle, kSuccess),
    ('partial', 'Partial Consent', 'Share some information — specify below', Icons.tune, kInfo),
    ('none', 'No Sharing', 'Do not share any information', Icons.block, kError),
  ];

  @override
  void initState() {
    super.initState();
    _consent = widget.profile[widget.consentKey]?.toString() ?? '';
    _detailsCtrl = TextEditingController(text: widget.profile[widget.detailsKey]?.toString() ?? '');
    _showDetails = _consent == 'partial';
  }

  @override
  void dispose() { _detailsCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: kDivider)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 24, height: 24, decoration: BoxDecoration(color: kPrimary.withAlpha(20), borderRadius: BorderRadius.circular(6)),
              child: const Icon(Icons.verified_user_outlined, color: kPrimary, size: 14)),
            const SizedBox(width: 8),
            Text('Information Sharing — ${widget.label}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kText)),
          ]),
          const SizedBox(height: 10),

          ..._options.map((o) {
            final isSelected = _consent == o.$1;
            final color = o.$5;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  setState(() {
                    _consent = o.$1;
                    _showDetails = o.$1 == 'partial';
                  });
                  widget.onChanged(widget.consentKey, o.$1);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? color.withAlpha(15) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isSelected ? color : kDivider, width: isSelected ? 1.5 : 1),
                  ),
                  child: Row(children: [
                    Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      size: 18, color: isSelected ? color : kTextLight),
                    const SizedBox(width: 8),
                    Icon(o.$4, size: 16, color: isSelected ? color : kTextLight),
                    const SizedBox(width: 8),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(o.$2, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? color : kText)),
                      Text(o.$3, style: TextStyle(fontSize: 9, color: kTextLight)),
                    ])),
                  ]),
                ),
              ),
            );
          }),

          // Partial consent details
          if (_showDetails) ...[
            const SizedBox(height: 6),
            TextField(
              controller: _detailsCtrl,
              maxLines: 3,
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                labelText: 'What information can be shared?',
                hintText: 'e.g. Appointment dates and medication names only, but not clinical notes',
                alignLabelWithHint: true,
                isDense: true,
              ),
              onChanged: (v) => widget.onChanged(widget.detailsKey, v),
            ),
          ],
        ]),
      ),
    );
  }
}
