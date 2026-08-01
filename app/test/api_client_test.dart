import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:traceagro_app/data/api_client.dart';

void main() {
  test(
    '401 encerra a sessão antes de manter dados protegidos na tela',
    () async {
      var unauthorized = false;
      final api = ApiClient(
        baseUrl: 'https://base.traceagro.test',
        tokenProvider: () => 'token',
        onUnauthorized: () => unauthorized = true,
        client: MockClient((_) async => http.Response('{}', 401)),
      );

      await expectLater(
        api.animals('property-1'),
        throwsA(isA<SessionExpiredException>()),
      );

      expect(unauthorized, isTrue);
      api.close();
    },
  );
}
