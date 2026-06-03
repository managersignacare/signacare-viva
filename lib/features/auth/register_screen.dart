import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// Patient self-registration — mirrors desktop patient registration fields.
class PatientRegisterScreen extends StatefulWidget {
  const PatientRegisterScreen({super.key});
  @override
  State<PatientRegisterScreen> createState() => _PatientRegisterState();
}

class _PatientRegisterState extends State<PatientRegisterScreen> {
  int _step = 0;
  final _formKey = GlobalKey<FormState>();

  // Step 0: Personal
  final _givenName = TextEditingController();
  final _familyName = TextEditingController();
  final _preferredName = TextEditingController();
  final _dob = TextEditingController();
  String _gender = '';
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  // Step 1: Address
  final _street = TextEditingController();
  final _suburb = TextEditingController();
  final _state = TextEditingController();
  final _postcode = TextEditingController();

  // Step 2: Next of Kin
  final _nokName = TextEditingController();
  final _nokRelationship = TextEditingController();
  final _nokPhone = TextEditingController();

  // Step 3: GP / Provider
  final _gpName = TextEditingController();
  final _gpPractice = TextEditingController();
  final _gpPhone = TextEditingController();

  // Step 4: Support Person
  final _supportName = TextEditingController();
  final _supportRelationship = TextEditingController();
  final _supportPhone = TextEditingController();

  bool _registering = false;
  String? _error;

  static const _steps = ['Personal', 'Address', 'Next of Kin', 'GP / Provider', 'Support Person'];
  static const _genders = ['Male', 'Female', 'Non-binary', 'Other', 'Prefer not to say'];

  @override
  void dispose() {
    for (final c in [_givenName, _familyName, _preferredName, _dob, _phone, _email, _password,
        _street, _suburb, _state, _postcode, _nokName, _nokRelationship, _nokPhone,
        _gpName, _gpPractice, _gpPhone, _supportName, _supportRelationship, _supportPhone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _register() async {
    setState(() { _registering = true; _error = null; });
    // TODO: POST to patient registration API endpoint when available
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration submitted — your clinic will activate your account'), backgroundColor: kSuccess));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(title: Text('Register — ${_steps[_step]}')),
      body: Column(children: [
        // Step indicator
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(children: List.generate(_steps.length, (i) => Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: i < _steps.length - 1 ? 4 : 0),
              decoration: BoxDecoration(
                color: i <= _step ? kPrimary : kDivider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ))),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (_step == 0) ..._personalFields(),
                if (_step == 1) ..._addressFields(),
                if (_step == 2) ..._nokFields(),
                if (_step == 3) ..._gpFields(),
                if (_step == 4) ..._supportFields(),

                if (_error != null) Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!, style: const TextStyle(color: kError, fontSize: 12)),
                ),

                const SizedBox(height: 24),
                Row(children: [
                  if (_step > 0) Expanded(child: OutlinedButton(
                    onPressed: () => setState(() => _step--),
                    child: const Text('Back'),
                  )),
                  if (_step > 0) const SizedBox(width: 12),
                  Expanded(child: ElevatedButton(
                    onPressed: _registering ? null : () {
                      if (_step < _steps.length - 1) {
                        setState(() => _step++);
                      } else {
                        _register();
                      }
                    },
                    child: _registering
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(_step < _steps.length - 1 ? 'Next' : 'Submit Registration'),
                  )),
                ]),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  List<Widget> _personalFields() => [
    const _SectionLabel('Your Details'),
    TextFormField(controller: _givenName, decoration: const InputDecoration(labelText: 'First Name *'),
      validator: (v) => v == null || v.isEmpty ? 'Required' : null),
    const SizedBox(height: 12),
    TextFormField(controller: _familyName, decoration: const InputDecoration(labelText: 'Last Name *'),
      validator: (v) => v == null || v.isEmpty ? 'Required' : null),
    const SizedBox(height: 12),
    TextFormField(controller: _preferredName, decoration: const InputDecoration(labelText: 'Preferred Name')),
    const SizedBox(height: 12),
    TextFormField(controller: _dob, decoration: const InputDecoration(labelText: 'Date of Birth *', hintText: 'DD/MM/YYYY'),
      keyboardType: TextInputType.datetime),
    const SizedBox(height: 12),
    DropdownButtonFormField<String>(
      initialValue: _gender.isEmpty ? null : _gender,
      decoration: const InputDecoration(labelText: 'Gender'),
      items: _genders.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
      onChanged: (v) => setState(() => _gender = v ?? ''),
    ),
    const SizedBox(height: 12),
    TextFormField(controller: _phone, decoration: const InputDecoration(labelText: 'Mobile Number *', prefixIcon: Icon(Icons.phone, size: 20)),
      keyboardType: TextInputType.phone, validator: (v) => v == null || v.length < 8 ? 'Enter mobile number' : null),
    const SizedBox(height: 12),
    TextFormField(controller: _email, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
    const SizedBox(height: 12),
    TextFormField(controller: _password, decoration: const InputDecoration(labelText: 'Create Password *'),
      obscureText: true, validator: (v) => v == null || v.length < 6 ? 'Min 6 characters' : null),
  ];

  List<Widget> _addressFields() => [
    const _SectionLabel('Your Address'),
    TextFormField(controller: _street, decoration: const InputDecoration(labelText: 'Street Address')),
    const SizedBox(height: 12),
    TextFormField(controller: _suburb, decoration: const InputDecoration(labelText: 'Suburb')),
    const SizedBox(height: 12),
    Row(children: [
      Expanded(child: TextFormField(controller: _state, decoration: const InputDecoration(labelText: 'State'))),
      const SizedBox(width: 12),
      Expanded(child: TextFormField(controller: _postcode, decoration: const InputDecoration(labelText: 'Postcode'), keyboardType: TextInputType.number)),
    ]),
  ];

  List<Widget> _nokFields() => [
    const _SectionLabel('Next of Kin / Emergency Contact'),
    const Text('This person will be contacted in an emergency', style: TextStyle(fontSize: 12, color: kTextLight)),
    const SizedBox(height: 12),
    TextFormField(controller: _nokName, decoration: const InputDecoration(labelText: 'Full Name')),
    const SizedBox(height: 12),
    TextFormField(controller: _nokRelationship, decoration: const InputDecoration(labelText: 'Relationship')),
    const SizedBox(height: 12),
    TextFormField(controller: _nokPhone, decoration: const InputDecoration(labelText: 'Phone Number'), keyboardType: TextInputType.phone),
  ];

  List<Widget> _gpFields() => [
    const _SectionLabel('GP / Primary Care Provider'),
    TextFormField(controller: _gpName, decoration: const InputDecoration(labelText: 'Doctor Name')),
    const SizedBox(height: 12),
    TextFormField(controller: _gpPractice, decoration: const InputDecoration(labelText: 'Practice Name')),
    const SizedBox(height: 12),
    TextFormField(controller: _gpPhone, decoration: const InputDecoration(labelText: 'Phone'), keyboardType: TextInputType.phone),
  ];

  List<Widget> _supportFields() => [
    const _SectionLabel('Support Person / Carer'),
    const Text('Someone who supports you in your recovery journey', style: TextStyle(fontSize: 12, color: kTextLight)),
    const SizedBox(height: 12),
    TextFormField(controller: _supportName, decoration: const InputDecoration(labelText: 'Full Name')),
    const SizedBox(height: 12),
    TextFormField(controller: _supportRelationship, decoration: const InputDecoration(labelText: 'Relationship')),
    const SizedBox(height: 12),
    TextFormField(controller: _supportPhone, decoration: const InputDecoration(labelText: 'Phone'), keyboardType: TextInputType.phone),
  ];
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kText)),
  );
}
