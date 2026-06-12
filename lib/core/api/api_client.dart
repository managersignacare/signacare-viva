import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _kBaseUrlKey = 'viva_base_url';
const _kDefaultBaseUrl = 'http://localhost:4000/api/v1';
const _kAccessTokenKey = 'access_token';
const _kRefreshTokenKey = 'refresh_token';
const _kPatientIdKey = 'patient_id';

/// Token storage — in-memory on web, secure keychain on native.
class _TokenStore {
  final Map<String, String> _mem = {};
  final FlutterSecureStorage? _secure = kIsWeb ? null
      : const FlutterSecureStorage(mOptions: MacOsOptions(useDataProtectionKeyChain: false));

  Future<String?> read(String key) async {
    if (_mem.containsKey(key)) return _mem[key];
    if (_secure != null) {
      try { final v = await _secure.read(key: key); if (v != null) _mem[key] = v; return v; } catch (_) {}
    }
    return null;
  }

  Future<void> write(String key, String value) async {
    _mem[key] = value;
    if (_secure != null) { try { await _secure.write(key: key, value: value); } catch (_) {} }
  }

  Future<void> delete(String key) async {
    _mem.remove(key);
    if (_secure != null) { try { await _secure.delete(key: key); } catch (_) {} }
  }
}

class PatientApiClient {
  PatientApiClient._();
  static final PatientApiClient instance = PatientApiClient._();

  final _store = _TokenStore();
  late final Dio _dio;
  bool _initialised = false;

  Future<void> init() async {
    if (_initialised) return;
    final baseUrl = await _store.read(_kBaseUrlKey) ?? _kDefaultBaseUrl;
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = _store._mem[_kAccessTokenKey];
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        options.headers['X-Client'] = 'patient-app';
        handler.next(options);
      },
      onError: (DioException e, handler) async {
        if (e.response?.statusCode == 401) {
          final refreshed = await _tryRefresh();
          if (refreshed) {
            e.requestOptions.headers['Authorization'] = 'Bearer ${_store._mem[_kAccessTokenKey]}';
            final retry = await _dio.fetch(e.requestOptions);
            return handler.resolve(retry);
          }
        }
        handler.next(e);
      },
    ));
    _initialised = true;
  }

  Future<bool> _tryRefresh() async {
    try {
      final rt = await _store.read(_kRefreshTokenKey);
      if (rt == null) return false;
      final resp = await _dio.post('/auth/refresh', data: {'refreshToken': rt});
      await storeTokens(accessToken: resp.data['accessToken'], refreshToken: resp.data['refreshToken'] ?? rt);
      return true;
    } catch (_) { return false; }
  }

  Future<void> storeTokens({required String accessToken, required String refreshToken}) async {
    await _store.write(_kAccessTokenKey, accessToken);
    await _store.write(_kRefreshTokenKey, refreshToken);
  }

  Future<void> clearTokens() async {
    await _store.delete(_kAccessTokenKey);
    await _store.delete(_kRefreshTokenKey);
    await _store.delete(_kPatientIdKey);
  }

  Future<String?> get accessToken => _store.read(_kAccessTokenKey);
  Future<String?> get patientId => _store.read(_kPatientIdKey);
  Future<void> setPatientId(String id) => _store.write(_kPatientIdKey, id);

  Future<String> getBaseUrl() async => await _store.read(_kBaseUrlKey) ?? _kDefaultBaseUrl;
  Future<void> setBaseUrl(String url) async {
    await _store.write(_kBaseUrlKey, url);
    _dio.options.baseUrl = url;
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? params}) async {
    await init(); return (await _dio.get(path, queryParameters: params)).data;
  }
  Future<dynamic> post(String path, {required Map<String, dynamic> data}) async {
    await init(); return (await _dio.post(path, data: data)).data;
  }
  Future<dynamic> patch(String path, {required Map<String, dynamic> data}) async {
    await init(); return (await _dio.patch(path, data: data)).data;
  }
  Future<dynamic> delete(String path) async {
    await init(); return (await _dio.delete(path)).data;
  }

  /// Stream a binary body to a local path. Used by Phase 11B's
  /// VivaDocumentCache to persist patient attachments returned via
  /// pre-signed URLs. Accepts absolute URLs because the signed blob
  /// URL lives outside our API base.
  Future<void> download(String url, String savePath) async {
    await init();
    await _dio.download(url, savePath);
  }

  Future<Map<String, dynamic>> login(String phone, String password) async {
    await init();
    // Use dedicated patient-app login endpoint (separate from staff auth)
    final r = await _dio.post('/patient-app/login', data: {'phone': phone, 'password': password},
        options: Options(headers: {'X-Client': 'patient-app'}));
    final body = Map<String, dynamic>.from(r.data);
    final at = body['accessToken'] as String?;
    final rt = body['refreshToken'] as String?;
    if (at != null) await storeTokens(accessToken: at, refreshToken: rt ?? '');
    // Store patient ID for API calls
    final patientId = (body['user'] as Map?)?['patientId'] as String?;
    if (patientId != null) await setPatientId(patientId);
    return body;
  }

  Future<Map<String, dynamic>> submitRegistrationRequest(Map<String, dynamic> payload) async {
    await init();
    final r = await _dio.post('/patient-app/register', data: payload,
        options: Options(headers: {'X-Client': 'patient-app'}));
    return Map<String, dynamic>.from(r.data as Map);
  }
}

final pApi = PatientApiClient.instance;
