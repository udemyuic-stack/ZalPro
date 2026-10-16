import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

String fakeJwt(String sub) {
  String enc(Object o) => base64Url.encode(utf8.encode(json.encode(o))).replaceAll('=', '');
  return '${enc({'alg': 'none'})}.${enc({'sub': sub})}.sig';
}

typedef Handler = Future<ResponseBody> Function(RequestOptions options);

class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  final Handler handler;
  final List<RequestOptions> calls = [];

  int count(String path) => calls.where((c) => c.path == path).length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    calls.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(Object body, int status, {Map<String, List<String>>? headers}) {
  return ResponseBody.fromString(
    json.encode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
      ...?headers,
    },
  );
}
