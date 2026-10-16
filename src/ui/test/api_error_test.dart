import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/services/api/api_error.dart';

ApiException ex(
  String code, {
  String message = '',
  Duration? retryAfter,
  List<Map<String, String>> errors = const [],
}) =>
    ApiException(code: code, message: message, retryAfter: retryAfter, errors: errors);

DioException dioError(Object? data, {Map<String, List<String>>? headers, int status = 400}) {
  final options = RequestOptions(path: '/x');
  return DioException(
    requestOptions: options,
    response: Response(
      requestOptions: options,
      statusCode: status,
      data: data,
      headers: Headers.fromMap(headers ?? {}),
    ),
  );
}

void main() {
  group('apiErrorText', () {
    final cases = <String, (ApiException, String)>{
      'invalid_credentials': (ex('invalid_credentials'), "Telefon raqam yoki parol noto'g'ri"),
      'phone_taken': (
        ex('phone_taken'),
        "Bu raqam bilan akkaunt allaqachon bor — Kirish'ni bosing",
      ),
      'wrong_password': (ex('wrong_password'), "Joriy parol noto'g'ri"),
      'too_many_attempts without retryAfter': (
        ex('too_many_attempts'),
        "Juda ko'p urinish. Birozdan so'ng qayta urinib ko'ring",
      ),
      'too_many_attempts 90s': (
        ex('too_many_attempts', retryAfter: const Duration(seconds: 90)),
        "Juda ko'p urinish. 2 daqiqadan so'ng qayta urinib ko'ring",
      ),
      'too_many_attempts 0s': (
        ex('too_many_attempts', retryAfter: Duration.zero),
        "Juda ko'p urinish. 1 daqiqadan so'ng qayta urinib ko'ring",
      ),
      'validation_error password': (
        ex('validation_error', errors: [
          {'field': 'body.password', 'message': 'short'},
        ]),
        "Parol kamida 8 belgi bo'lsin",
      ),
      'validation_error phone': (
        ex('validation_error', errors: [
          {'field': 'body.phone', 'message': 'bad'},
        ]),
        "Telefon raqam noto'g'ri",
      ),
      'validation_error other with message': (
        ex('validation_error', message: 'Bad name', errors: [
          {'field': 'body.name', 'message': 'bad'},
        ]),
        'Bad name',
      ),
      'validation_error other without message': (
        ex('validation_error'),
        "Ma'lumotlar noto'g'ri",
      ),
      'network_error': (ex('network_error'), 'Internet aloqasini tekshiring'),
      'unknown with message': (ex('weird', message: 'Something'), 'Something'),
      'unknown without message': (ex('weird'), 'weird'),
    };

    cases.forEach((name, c) {
      test(name, () => expect(apiErrorText(c.$1), c.$2));
    });

    test('non ApiException falls back to toString', () {
      expect(apiErrorText(StateError('x')), StateError('x').toString());
    });
  });

  group('ApiException.fromDio', () {
    test('parses detail code, message, errors, status and Retry-After', () {
      final e = ApiException.fromDio(dioError(
        {
          'detail': {
            'code': 'validation_error',
            'message': 'Invalid',
            'errors': [
              {'field': 'body.phone', 'message': 'bad'},
            ],
          },
        },
        headers: {
          'retry-after': ['90'],
        },
        status: 422,
      ));

      expect(e.code, 'validation_error');
      expect(e.message, 'Invalid');
      expect(e.status, 422);
      expect(e.retryAfter, const Duration(seconds: 90));
      expect(e.errors, [
        {'field': 'body.phone', 'message': 'bad'},
      ]);
      expect(e.isNetwork, isFalse);
    });

    test('non JSON body yields http_error', () {
      final e = ApiException.fromDio(dioError('<html>', status: 502));
      expect(e.code, 'http_error');
      expect(e.message, '');
      expect(e.status, 502);
      expect(e.retryAfter, isNull);
    });

    test('invalid Retry-After is ignored', () {
      final e = ApiException.fromDio(dioError(
        {
          'detail': {'code': 'too_many_attempts'}
        },
        headers: {
          'retry-after': ['soon'],
        },
        status: 429,
      ));
      expect(e.retryAfter, isNull);
    });

    test('no response yields network_error', () {
      final e = ApiException.fromDio(DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.connectionError,
        message: 'down',
      ));
      expect(e.isNetwork, isTrue);
      expect(e.status, isNull);
      expect(e.message, 'down');
    });
  });
}
