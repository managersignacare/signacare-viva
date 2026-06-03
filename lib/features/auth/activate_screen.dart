import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme.dart';
import '../../core/api/api_client.dart';

/// Patient activation — enter 6-digit code from clinician, set password.
class ActivateScreen extends StatefulWidget {
  const ActivateScreen({super.key});
  @override
  State<ActivateScreen> createState() => _ActivateState();
}

class _ActivateState extends State<ActivateScreen> {
  final _codeCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  bool _activating = false;
  String? _error;
  String? _success;
  String? _phone;

  String? _normalizeDobForRequest(String rawDob) {
    final value = rawDob.trim();
    if (value.isEmpty) return null;
    final iso = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (iso.hasMatch(value)) return value;
    final au = RegExp(r'^(\d{2})\/(\d{2})\/(\d{4})$').firstMatch(value);
    if (au == null) return value;
    final dd = au.group(1)!;
    final mm = au.group(2)!;
    final yyyy = au.group(3)!;
    return '$yyyy-$mm-$dd';
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _dobCtrl.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    final code = _codeCtrl.text.trim();
    final pass = _passCtrl.text;
    final confirm = _confirmCtrl.text;

    final phone = _phoneCtrl.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code from your clinician');
      return;
    }
    if (phone.length < 8) {
      setState(() => _error = 'Enter your mobile number');
      return;
    }
    if (pass.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters');
      return;
    }
    if (pass != confirm) {
      setState(() => _error = 'Passwords do not match');
      return;
    }
    final normalizedDob = _normalizeDobForRequest(_dobCtrl.text);

    setState(() {
      _activating = true;
      _error = null;
    });
    try {
      final payload = <String, dynamic>{
        'code': code,
        'phone': phone,
        'password': pass,
      };
      if (normalizedDob != null) {
        payload['dob'] = normalizedDob;
      }
      final data = await pApi.post('/patient-app/activate', data: payload);
      if (data is! Map) {
        throw const FormatException('Unexpected activation response shape');
      }
      final result = Map<String, dynamic>.from(data);
      setState(() {
        _success = (result['message'] as String?) ?? 'Account activated!';
        _phone = result['phone'] as String?;
        _activating = false;
      });
    } on DioException catch (e) {
      // Audit Tier 1.5 (HIGH-J1) — surface the backend error message
      // instead of a generic "Please try again". The activate endpoint
      // returns `{ message: string }` on known failures (invalid code,
      // expired code, DOB mismatch, phone already claimed). Prefer
      // server `message`; fall back to DioException.message, then a
      // generic copy.
      final responseData = e.response?.data;
      String? serverMessage;
      if (responseData is Map && responseData['message'] is String) {
        serverMessage = responseData['message'] as String;
      }
      if (serverMessage == null &&
          responseData is Map &&
          responseData['error'] is String) {
        serverMessage = responseData['error'] as String;
      }
      if (serverMessage == null &&
          responseData is Map &&
          responseData['title'] is String) {
        serverMessage = responseData['title'] as String;
      }
      if (serverMessage == null && responseData is Map) {
        final details = responseData['details'];
        if (details is List && details.isNotEmpty) {
          final first = details.first;
          if (first is Map && first['message'] is String) {
            serverMessage = first['message'] as String;
          }
        }
      }
      setState(() {
        _error = serverMessage != null
            ? 'Activation failed: $serverMessage'
            : (e.message != null && e.message!.isNotEmpty
                  ? 'Activation failed: ${e.message}'
                  : 'Activation failed. Check your connection and try again.');
        _activating = false;
      });
    } on FormatException catch (e) {
      setState(() {
        _error = 'Activation response malformed: ${e.message}';
        _activating = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Activation failed: $e';
        _activating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(title: const Text('Activate Account')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _success != null ? _successView() : _formView(),
      ),
    );
  }

  Widget _successView() => Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      const SizedBox(height: 40),
      Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: kSuccess.withAlpha(20),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_circle, color: kSuccess, size: 40),
      ),
      const SizedBox(height: 20),
      const Text(
        'Account Activated!',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: kText,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        _success!,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, color: kTextLight),
      ),
      if (_phone != null) ...[
        const SizedBox(height: 12),
        Text(
          'Your login: $_phone',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: kPrimary,
          ),
        ),
      ],
      const SizedBox(height: 32),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Go to Sign In'),
        ),
      ),
    ],
  );

  Widget _formView() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kPrimary.withAlpha(10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How to activate:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: kText,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '1. Your clinician will give you a 6-digit code',
              style: TextStyle(fontSize: 13, color: kText),
            ),
            Text(
              '2. Enter the code below',
              style: TextStyle(fontSize: 13, color: kText),
            ),
            Text(
              '3. Set your password',
              style: TextStyle(fontSize: 13, color: kText),
            ),
            Text(
              '4. Sign in with your phone number',
              style: TextStyle(fontSize: 13, color: kText),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),

      const Text(
        'Activation Code',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: kText,
        ),
      ),
      const SizedBox(height: 6),
      TextField(
        controller: _codeCtrl,
        keyboardType: TextInputType.number,
        maxLength: 6,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: 12,
          color: kPrimary,
        ),
        textAlign: TextAlign.center,
        decoration: const InputDecoration(counterText: '', hintText: '000000'),
      ),
      const SizedBox(height: 16),

      const Text(
        'Your Mobile Number',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: kText,
        ),
      ),
      const SizedBox(height: 6),
      TextField(
        controller: _phoneCtrl,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(
          hintText: '04XX XXX XXX',
          prefixIcon: Icon(Icons.phone, size: 20),
        ),
      ),
      const SizedBox(height: 16),

      const Text(
        'Date of Birth (for verification)',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: kText,
        ),
      ),
      const SizedBox(height: 6),
      TextField(
        controller: _dobCtrl,
        keyboardType: TextInputType.datetime,
        decoration: const InputDecoration(
          hintText: 'DD/MM/YYYY or YYYY-MM-DD (optional)',
        ),
      ),
      const SizedBox(height: 16),

      const Text(
        'Create Password',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: kText,
        ),
      ),
      const SizedBox(height: 6),
      TextField(
        controller: _passCtrl,
        obscureText: true,
        decoration: const InputDecoration(
          labelText: 'Password (min 8 characters)',
        ),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _confirmCtrl,
        obscureText: true,
        decoration: const InputDecoration(labelText: 'Confirm Password'),
      ),

      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: kError.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _error!,
              style: const TextStyle(color: kError, fontSize: 13),
            ),
          ),
        ),

      const SizedBox(height: 24),
      ElevatedButton(
        onPressed: _activating ? null : _activate,
        child: _activating
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : const Text('Activate Account'),
      ),
    ],
  );
}
