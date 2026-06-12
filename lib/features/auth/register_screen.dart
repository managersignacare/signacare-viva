import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
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

  // Step 0: Clinic
  final _clinicName = TextEditingController();

  // Step 0: Personal
  final _givenName = TextEditingController();
  final _familyName = TextEditingController();
  final _preferredName = TextEditingController();
  final _dob = TextEditingController();
  String _gender = '';
  final _phone = TextEditingController();
  final _email = TextEditingController();

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
  bool _consentToContact = false;
  String? _error;

  static const _steps = ['Clinic', 'Personal', 'Address', 'Next of Kin', 'GP / Provider', 'Support Person'];
  static const _genders = ['Male', 'Female', 'Non-binary', 'Other', 'Prefer not to say'];

  @override
  void dispose() {
    for (final c in [_clinicName, _givenName, _familyName, _preferredName, _dob, _phone, _email,
        _street, _suburb, _state, _postcode, _nokName, _nokRelationship, _nokPhone,
        _gpName, _gpPractice, _gpPhone, _supportName, _supportRelationship, _supportPhone]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _normalizeDobForRequest(String rawDob) {
    final value = rawDob.trim();
    if (value.isEmpty) return null;
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return value;
    final au = RegExp(r'^(\d{2})\/(\d{2})\/(\d{4})$').firstMatch(value);
    if (au == null) return value;
    return '${au.group(3)!}-${au.group(2)!}-${au.group(1)!}';
  }

  bool _isAcceptedDob(String rawDob) {
    final normalized = _normalizeDobForRequest(rawDob);
    return normalized != null && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(normalized);
  }

  bool _hasRequiredDetails() {
    return _givenName.text.trim().isNotEmpty &&
        _familyName.text.trim().isNotEmpty &&
        _isAcceptedDob(_dob.text) &&
        _phone.text.trim().length >= 8;
  }

  String _serverError(DioException e) {
    final responseData = e.response?.data;
    if (responseData is Map && responseData['error'] is String) {
      return responseData['error'] as String;
    }
    if (responseData is Map && responseData['message'] is String) {
      return responseData['message'] as String;
    }
    final details = responseData is Map ? responseData['details'] : null;
    if (details is List && details.isNotEmpty) {
      final first = details.first;
      if (first is Map && first['message'] is String) return first['message'] as String;
    }
    return e.message ?? 'Check your connection and try again.';
  }

  Future<void> _register() async {
    if (!(_formKey.currentState?.validate() ?? false) || !_hasRequiredDetails()) {
      setState(() => _error = 'Please complete your name, date of birth and mobile number before submitting.');
      return;
    }
    if (!_consentToContact) {
      setState(() => _error = 'Please confirm that the clinic may contact you about this registration request.');
      return;
    }
    final normalizedDob = _normalizeDobForRequest(_dob.text);
    if (normalizedDob == null || !_isAcceptedDob(_dob.text)) {
      setState(() => _error = 'Enter date of birth as DD/MM/YYYY or YYYY-MM-DD.');
      return;
    }

    final payload = <String, dynamic>{
      if (_clinicName.text.trim().isNotEmpty) 'clinicName': _clinicName.text.trim(),
      'givenName': _givenName.text.trim(),
      'familyName': _familyName.text.trim(),
      if (_preferredName.text.trim().isNotEmpty) 'preferredName': _preferredName.text.trim(),
      'dateOfBirth': normalizedDob,
      if (_gender.isNotEmpty) 'gender': _gender,
      'phoneMobile': _phone.text.trim(),
      if (_email.text.trim().isNotEmpty) 'email': _email.text.trim(),
      'address': {
        if (_street.text.trim().isNotEmpty) 'street': _street.text.trim(),
        if (_suburb.text.trim().isNotEmpty) 'suburb': _suburb.text.trim(),
        if (_state.text.trim().isNotEmpty) 'state': _state.text.trim(),
        if (_postcode.text.trim().isNotEmpty) 'postcode': _postcode.text.trim(),
      },
      'nextOfKin': {
        if (_nokName.text.trim().isNotEmpty) 'name': _nokName.text.trim(),
        if (_nokRelationship.text.trim().isNotEmpty) 'relationship': _nokRelationship.text.trim(),
        if (_nokPhone.text.trim().isNotEmpty) 'phone': _nokPhone.text.trim(),
      },
      'gp': {
        if (_gpName.text.trim().isNotEmpty) 'name': _gpName.text.trim(),
        if (_gpPractice.text.trim().isNotEmpty) 'practice': _gpPractice.text.trim(),
        if (_gpPhone.text.trim().isNotEmpty) 'phone': _gpPhone.text.trim(),
      },
      'supportPerson': {
        if (_supportName.text.trim().isNotEmpty) 'name': _supportName.text.trim(),
        if (_supportRelationship.text.trim().isNotEmpty) 'relationship': _supportRelationship.text.trim(),
        if (_supportPhone.text.trim().isNotEmpty) 'phone': _supportPhone.text.trim(),
      },
      'clientRequestId': 'viva-${DateTime.now().millisecondsSinceEpoch}',
      'consentToContact': _consentToContact,
    };

    setState(() { _registering = true; _error = null; });
    try {
      final result = await pApi.submitRegistrationRequest(payload);
      final message = result['message'] as String? ??
          'Registration submitted. Your clinic will contact you about activation.';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: kSuccess));
      Navigator.pop(context);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _registering = false;
        _error = 'Registration failed: ${_serverError(e)}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _registering = false;
        _error = 'Registration failed: $e';
      });
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
                if (_step == 0) ..._clinicFields(),
                if (_step == 1) ..._personalFields(),
                if (_step == 2) ..._addressFields(),
                if (_step == 3) ..._nokFields(),
                if (_step == 4) ..._gpFields(),
                if (_step == 5) ..._supportFields(),

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
                        if (_formKey.currentState?.validate() ?? false) {
                          setState(() => _step++);
                        }
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

  List<Widget> _clinicFields() => [
    const _SectionLabel('Clinic / Service'),
    const Text(
      'If your app has been preconfigured for one clinic, you can leave this blank. Otherwise enter the clinic or service name.',
      style: TextStyle(fontSize: 12, color: kTextLight),
    ),
    const SizedBox(height: 12),
    TextFormField(
      controller: _clinicName,
      decoration: const InputDecoration(labelText: 'Clinic or service name'),
      textInputAction: TextInputAction.next,
    ),
  ];

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
      keyboardType: TextInputType.datetime,
      validator: (v) => !_isAcceptedDob(v ?? '') ? 'Enter DD/MM/YYYY or YYYY-MM-DD' : null),
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
    const SizedBox(height: 16),
    CheckboxListTile(
      value: _consentToContact,
      onChanged: (value) => setState(() => _consentToContact = value ?? false),
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      title: const Text('I consent to the clinic contacting me about this registration request.'),
      subtitle: const Text(
        'Submitting registration creates a reviewed intake request only. It does not create a patient account until clinic staff approve and invite you.',
      ),
    ),
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
