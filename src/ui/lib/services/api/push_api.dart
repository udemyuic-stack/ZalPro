import 'package:flutter/foundation.dart';

import 'api_client.dart';

class PushApi {
  PushApi(this._client);

  final ApiClient _client;

  Future<void> add(String token, String platform) =>
      _client.request<void>('POST', '/v1/users/me/push-tokens',
          data: {'token': token, 'platform': platform});

  Future<void> remove(String token) =>
      _client.request<void>('DELETE', '/v1/users/me/push-tokens/${Uri.encodeComponent(token)}');

  static String currentPlatform() {
    if (kIsWeb) return 'web';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    return 'android';
  }
}
