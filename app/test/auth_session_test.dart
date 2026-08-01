import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:traceagro_app/core/auth/auth_session.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

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

  test('servidor não pode tornar o login opcional', () async {
    final session = AuthSession(
      baseUrl: 'https://base.traceagro.test',
      client: MockClient(
        (_) async => http.Response('{"required":false,"mode":"dev"}', 200),
      ),
    );

    await session.bootstrap();

    expect(session.initialized, isTrue);
    expect(session.requiresLogin, isTrue);
    expect(session.isAuthenticated, isFalse);
  });

  test('login carrega roles e permissões da identidade validada', () async {
    final token = _token(expiresIn: const Duration(hours: 1));
    final session = AuthSession(
      baseUrl: 'https://base.traceagro.test',
      client: MockClient((request) async {
        expect(request.url.path, '/v1/auth/dev-login');
        return http.Response(
          jsonEncode({
            'accessToken': token,
            'principal': {
              'organizationId': 'org-1',
              'actorId': 'actor-1',
              'deviceId': 'device-1',
              'propertyId': 'property-1',
              'propertyName': 'Fazenda Teste',
              'name': 'Gestora Teste',
              'email': 'gestora@example.com',
              'roles': ['ADMO'],
              'permissions': ['users.manage'],
            },
          }),
          201,
        );
      }),
    );

    final loggedIn = await session.login('gestora@example.com', 'segredo');

    expect(loggedIn, isTrue);
    expect(session.isAuthenticated, isTrue);
    expect(session.roles, ['ADMO']);
    expect(session.can('users.manage'), isTrue);
    expect(session.identity.actorId, 'actor-1');
  });

  test('perfil administrativo antigo mantém a entrada da central visível', () {
    final session = AuthSession(baseUrl: 'https://base.traceagro.test')
      ..roles = const ['ADMO'];

    expect(session.canManageUsers, isTrue);
  });

  test('token local expirado não mantém a operação aberta', () async {
    SharedPreferences.setMockInitialValues({
      'traceagro.auth.token': _token(expiresIn: const Duration(minutes: -1)),
      'traceagro.auth.identity': jsonEncode({
        'organizationId': 'org-1',
        'actorId': 'actor-1',
        'deviceId': 'device-1',
        'propertyId': 'property-1',
        'appVersion': '0.2.0',
      }),
    });
    final session = AuthSession(baseUrl: 'https://base.traceagro.test');

    await session.restore();

    expect(session.isAuthenticated, isFalse);
    expect(session.token, isNull);
  });

  test(
    'falha temporária da API preserva uma sessão local ainda válida',
    () async {
      SharedPreferences.setMockInitialValues({
        'traceagro.auth.token': _token(expiresIn: const Duration(hours: 1)),
        'traceagro.auth.identity': jsonEncode({
          'organizationId': 'org-1',
          'actorId': 'actor-1',
          'deviceId': 'device-1',
          'propertyId': 'property-1',
          'appVersion': '0.2.0',
          'roles': ['OPER'],
        }),
      });
      final session = AuthSession(
        baseUrl: 'https://base.traceagro.test',
        client: MockClient((request) async {
          if (request.url.path.endsWith('/auth/config')) {
            return http.Response('{"required":true,"mode":"dev"}', 200);
          }
          return http.Response('{"message":"unavailable"}', 503);
        }),
      );

      await session.restore();
      await session.bootstrap();

      expect(session.isAuthenticated, isTrue);
      expect(session.identity.actorId, 'actor-1');
      expect(session.feedbackKind, AuthFeedbackKind.service);
    },
  );
}

String _token({required Duration expiresIn}) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final expiresAt =
      DateTime.now().add(expiresIn).millisecondsSinceEpoch ~/ 1000;
  return '${encode({'alg': 'HS256'})}.${encode({'exp': expiresAt})}.signature';
}
