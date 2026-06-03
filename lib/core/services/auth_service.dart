import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';

class PatientUser {
  final String id;
  final String patientId;
  final String? givenName;
  final String? familyName;
  final String? phone;
  final String? email;

  const PatientUser({required this.id, required this.patientId, this.givenName, this.familyName, this.phone, this.email});

  String get displayName => [givenName, familyName].where((s) => s != null && s.isNotEmpty).join(' ');

  factory PatientUser.fromJson(Map<String, dynamic> j) => PatientUser(
    id: j['id'] as String? ?? '',
    patientId: j['patientId'] as String? ?? j['id'] as String? ?? '',
    givenName: j['givenName'] as String?,
    familyName: j['familyName'] as String?,
    phone: j['phoneMobile'] as String? ?? j['email'] as String?,
    email: j['email'] as String?,
  );
}

class PatientAuthState {
  final PatientUser? user;
  final bool isLoading;
  final String? error;
  const PatientAuthState({this.user, this.isLoading = false, this.error});
  bool get isAuthenticated => user != null;
}

class PatientAuthNotifier extends StateNotifier<PatientAuthState> {
  PatientAuthNotifier() : super(const PatientAuthState(isLoading: true)) { _checkToken(); }

  Future<void> _checkToken() async {
    try {
      final token = await pApi.accessToken;
      if (token != null) {
        final data = await pApi.get('/patient-app/me');
        final user = PatientUser.fromJson(Map<String, dynamic>.from(data as Map));
        state = PatientAuthState(user: user);
      } else {
        state = const PatientAuthState();
      }
    } catch (_) {
      state = const PatientAuthState();
    }
  }

  Future<bool> login(String phone, String password) async {
    state = const PatientAuthState(isLoading: true);
    try {
      final data = await pApi.login(phone, password);
      final userData = (data['user'] as Map<String, dynamic>?) ?? data;
      final user = PatientUser.fromJson(Map<String, dynamic>.from(userData));
      await pApi.setPatientId(user.patientId);
      state = PatientAuthState(user: user);
      return true;
    } catch (e) {
      state = PatientAuthState(error: _parseError(e));
      return false;
    }
  }

  void setUser(PatientUser user) => state = PatientAuthState(user: user);

  Future<void> logout() async {
    try { await pApi.post('/patient-app/logout', data: {}); } catch (_) {}
    await pApi.clearTokens();
    state = const PatientAuthState();
  }

  String _parseError(dynamic e) {
    final msg = e.toString();
    if (msg.contains('401') || msg.contains('Invalid')) return 'Invalid phone number or password';
    if (msg.contains('Socket') || msg.contains('connection')) return 'Cannot reach server';
    return 'Login failed. Please try again.';
  }
}

final patientAuthProvider = StateNotifierProvider<PatientAuthNotifier, PatientAuthState>((_) => PatientAuthNotifier());
