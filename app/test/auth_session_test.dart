import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:traceagro_app/core/auth/auth_session.dart';

void main() {
  test('credencial recusada recebe mensagem clara para o operador', () async {
    final session = AuthSession(
      baseUrl: 'https://base.traceagro.test',
      client: MockClient(
        (_) async => http.Response('{"message":"unauthorized"}', 401),
      ),
    );

    final loggedIn = await session.login('joao@santarita.example', 'invalida');

    expect(loggedIn, isFalse);
    expect(session.feedbackKind, AuthFeedbackKind.credentials);
    expect(
      session.error,
      'E-mail ou senha não conferem. Revise os dados e tente de novo.',
    );
  });

  test('falha de rede não expõe exceção técnica no login', () async {
    final session = AuthSession(
      baseUrl: 'https://base.traceagro.test',
      client: MockClient(
        (_) async => throw http.ClientException('Failed to fetch'),
      ),
    );

    await session.bootstrap();

    expect(session.requiresLogin, isTrue);
    expect(session.feedbackKind, AuthFeedbackKind.connection);
    expect(
      session.error,
      'Não foi possível alcançar a base de campo. Confira a conexão e tente novamente.',
    );
    expect(session.error, isNot(contains('ClientException')));
  });
}
