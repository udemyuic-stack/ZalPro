import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/api_config.dart';
import 'api_error.dart';
import 'session_store.dart';
import 'upgrade_gate.dart';

class ApiClient {
  ApiClient({
    required SessionStore store,
    String baseUrl = apiUrl,
    HttpClientAdapter? adapter,
  })  : _store = store,
        _dio = Dio(BaseOptions(baseUrl: baseUrl, connectTimeout: const Duration(seconds: 15))),
        _bare = Dio(BaseOptions(baseUrl: baseUrl, connectTimeout: const Duration(seconds: 15))),
        _upload = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15))) {
    if (adapter != null) {
      _dio.httpClientAdapter = adapter;
      _bare.httpClientAdapter = adapter;
      _upload.httpClientAdapter = adapter;
    }
    _dio.interceptors.add(InterceptorsWrapper(onRequest: _onRequest, onError: _onError));
  }

  static const _retriedKey = 'retried';
  static const _noAuthKey = 'noAuth';

  final SessionStore _store;
  final Dio _dio;
  final Dio _bare;
  final Dio _upload;
  final _changes = StreamController<String?>.broadcast();
  String? _access;
  String? _userId;
  Future<bool>? _inflight;

  String? get accessToken => _access;
  String? get userId => _userId;
  Stream<String?> get userChanges => _changes.stream;

  void setAppVersion(String version) {
    _dio.options.headers[appVersionHeader] = version;
    _bare.options.headers[appVersionHeader] = version;
  }

  ApiException _fail(DioException e) {
    final error = ApiException.fromDio(e);
    if (error.isUpgradeRequired) {
      upgradeRequired.value = UpgradeInfo(downloadUrl: error.downloadUrl);
    }
    return error;
  }

  Future<void> restore() async {
    final refresh = await _store.readRefreshToken();
    if (refresh == null) return;
    try {
      await refreshSession();
    } on ApiException {
      return;
    }
  }

  Future<void> login(String phone, String password) async {
    final data = await _post('/v1/auth/login', {'phone': phone, 'password': password});
    await _adopt(data);
  }

  Future<void> register(String name, String phone, String password) async {
    final data = await _post('/v1/auth/register', {
      'name': name,
      'phone': phone,
      'password': password,
    });
    await _adopt(data);
  }

  Future<void> logout() async {
    final refresh = await _store.readRefreshToken();
    if (refresh != null && _access != null) {
      try {
        await request<void>('POST', '/v1/auth/logout', data: {'refresh_token': refresh});
      } on ApiException {
        await clearSession();
      }
    }
    await clearSession();
  }

  Future<void> clearSession() async {
    _access = null;
    await _store.clear();
    _setUser(null);
  }

  Future<bool> refreshSession() => _inflight ??= _refresh().whenComplete(() => _inflight = null);

  Future<bool> _refresh() async {
    final token = await _store.readRefreshToken();
    if (token == null) {
      await clearSession();
      return false;
    }
    try {
      final res = await _bare.post<Map<String, dynamic>>(
        '/v1/auth/refresh',
        data: {'refresh_token': token},
      );
      await _adopt(res.data!);
      return true;
    } on DioException catch (e) {
      final error = _fail(e);
      if (error.isNetwork || error.isUpgradeRequired || (error.status ?? 0) >= 500) throw error;
      await clearSession();
      return false;
    }
  }

  Future<void> _adopt(Map<String, dynamic> pair) async {
    final access = pair['access_token'] as String;
    await _store.writeRefreshToken(pair['refresh_token'] as String);
    _access = access;
    _setUser(subjectOf(access));
  }

  void _setUser(String? id) {
    _userId = id;
    _changes.add(id);
  }

  Future<Map<String, dynamic>> _post(String path, Object body) async {
    try {
      final res = await _bare.post<Map<String, dynamic>>(path, data: body);
      return res.data!;
    } on DioException catch (e) {
      throw _fail(e);
    }
  }

  Future<T?> request<T>(
    String method,
    String path, {
    Object? data,
    Map<String, dynamic>? query,
  }) async {
    try {
      final res = await _dio.request<T>(
        path,
        data: data,
        queryParameters: query,
        options: Options(method: method),
      );
      return res.data;
    } on DioException catch (e) {
      throw _fail(e);
    }
  }

  Future<void> uploadBytes(
    String url,
    Uint8List bytes, {
    String contentType = 'image/jpeg',
    void Function(int sent, int total)? onProgress,
  }) async {
    try {
      await _upload.put<void>(
        url,
        data: bytes,
        options: Options(contentType: contentType),
        onSendProgress: onProgress,
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Map<String, dynamic>> getJson(String path, {Map<String, dynamic>? query}) async =>
      (await request<Map<String, dynamic>>('GET', path, query: query))!;

  Future<List<dynamic>> getList(String path, {Map<String, dynamic>? query}) async =>
      (await request<List<dynamic>>('GET', path, query: query))!;

  void _onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _access;
    if (token != null && options.extra[_noAuthKey] != true) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  Future<void> _onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final retryable = err.response?.statusCode == 401 &&
        options.extra[_retriedKey] != true &&
        options.extra[_noAuthKey] != true;
    if (!retryable) return handler.next(err);
    try {
      if (!await refreshSession()) return handler.next(err);
    } on ApiException {
      return handler.next(err);
    }
    options.extra[_retriedKey] = true;
    options.headers['Authorization'] = 'Bearer $_access';
    try {
      handler.resolve(await _dio.fetch<dynamic>(options));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  void dispose() {
    _changes.close();
    _dio.close();
    _bare.close();
    _upload.close();
  }
}

String? subjectOf(String jwt) {
  final parts = jwt.split('.');
  if (parts.length != 3) return null;
  try {
    final payload = json.decode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
    return payload is Map ? payload['sub'] as String? : null;
  } on FormatException {
    return null;
  }
}
