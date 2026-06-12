import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/theme.dart';
import '../../core/services/auth_service.dart';
import '../../core/api/api_client.dart';
import '../home/home_screen.dart';
import 'activate_screen.dart';
import 'register_screen.dart';

class PatientLoginScreen extends ConsumerStatefulWidget {
  const PatientLoginScreen({super.key});
  @override
  ConsumerState<PatientLoginScreen> createState() => _PatientLoginState();
}

class _PatientLoginState extends ConsumerState<PatientLoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;
  bool _showUrl = false;
  final _urlCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    pApi.getBaseUrl().then((url) => _urlCtrl.text = url);
  }

  @override
  void dispose() { _phoneCtrl.dispose(); _passCtrl.dispose(); _urlCtrl.dispose(); super.dispose(); }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(patientAuthProvider.notifier).login(_phoneCtrl.text.trim(), _passCtrl.text);
    if (ok && mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const PatientHomeScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(patientAuthProvider);

    return Scaffold(
      backgroundColor: kSurface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Form(
            key: _formKey,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SizedBox(height: 24),
              Center(child: SvgPicture.asset('assets/signacare-logo.svg', width: 52, height: 52,
                colorFilter: const ColorFilter.mode(kPrimary, BlendMode.srcIn))),
              const SizedBox(height: 14),
              const Center(child: Text('Viva', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: kPrimary))),
              const Center(child: Text('by Signacare', style: TextStyle(fontSize: 13, color: kTextLight))),
              const SizedBox(height: 8),
              const Center(child: Text('Your Wellbeing Companion', style: TextStyle(fontSize: 12, color: kTextLight))),
              const SizedBox(height: 40),

              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Mobile number or email', prefixIcon: Icon(Icons.phone_outlined, size: 20)),
                validator: (v) => (v == null || v.length < 4) ? 'Enter your mobile number or email' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passCtrl,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _login(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) => (v == null || v.length < 4) ? 'Enter your password' : null,
              ),
              const SizedBox(height: 8),

              if (authState.error != null)
                Container(
                  padding: const EdgeInsets.all(10), margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(color: kError.withAlpha(20), borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    const Icon(Icons.error_outline, color: kError, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(authState.error!, style: const TextStyle(color: kError, fontSize: 13))),
                  ]),
                ),

              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: authState.isLoading ? null : _login,
                child: authState.isLoading
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text('Sign In'),
              ),
              const SizedBox(height: 16),

              OutlinedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ActivateScreen())),
                icon: const Icon(Icons.qr_code_2),
                label: const Text('I Have an Activation Code'),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PatientRegisterScreen())),
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('Request Access / Register'),
              ),
              const SizedBox(height: 20),

              Center(child: TextButton.icon(
                onPressed: () => setState(() => _showUrl = !_showUrl),
                icon: Icon(_showUrl ? Icons.expand_less : Icons.settings_ethernet, size: 16, color: kTextLight),
                label: Text(_showUrl ? 'Hide' : 'Server settings', style: const TextStyle(color: kTextLight, fontSize: 12)),
              )),
              if (_showUrl) ...[
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: TextFormField(controller: _urlCtrl, decoration: const InputDecoration(hintText: 'http://...:4000/api/v1'))),
                  const SizedBox(width: 8),
                  ElevatedButton(onPressed: () async {
                    await pApi.setBaseUrl(_urlCtrl.text.trim());
                    if (!context.mounted) {
                      return;
                    }
                    setState(() => _showUrl = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('URL saved')),
                    );
                  }, style: ElevatedButton.styleFrom(minimumSize: const Size(60, 48)), child: const Text('Save')),
                ]),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
