import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:traceagro_app/core/auth/auth_session.dart';
import 'package:traceagro_app/core/theme/theme.dart';
import 'package:traceagro_app/core/ui_profile/ui_preferences.dart';
import 'package:traceagro_app/core/ui_profile/ui_profile.dart';
import 'package:traceagro_app/core/ui_profile/ui_profile_resolver.dart';
import 'package:traceagro_app/core/ui_profile/ui_profile_scope.dart';
import 'package:traceagro_app/core/widgets/ui_profile_selector.dart';

/// Perfis de interface (Doc 20). O perfil só organiza a tela: estes testes
/// cobrem escolha automática, escolha manual e a preferência por usuário num
/// aparelho compartilhado.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('perfil automático pelos papéis', () {
    test('cada papel recebe o perfil documentado', () {
      const expected = {
        'PROD': UiProfile.management,
        'ADMO': UiProfile.management,
        'ADMP': UiProfile.management,
        'VETE': UiProfile.technical,
        'TECN': UiProfile.field,
        'OPER': UiProfile.operator,
        'AUDI': UiProfile.management,
        'CERT': UiProfile.management,
        'TRAN': UiProfile.field,
        'FRIG': UiProfile.field,
      };
      expected.forEach((role, profile) {
        expect(defaultUiProfileFor([role]), profile, reason: role);
      });
    });

    test('quem acumula papéis recebe o do papel mais amplo', () {
      expect(defaultUiProfileFor(['OPER', 'PROD']), UiProfile.management);
      expect(defaultUiProfileFor(['OPER', 'VETE']), UiProfile.technical);
      expect(defaultUiProfileFor(['OPER', 'TECN']), UiProfile.field);
    });

    test('sem papel reconhecido cai em Campo', () {
      expect(defaultUiProfileFor(const []), UiProfile.field);
      expect(defaultUiProfileFor(['PUBL']), UiProfile.field);
      expect(defaultUiProfileFor(['XYZ']), UiProfile.field);
    });
  });

  group('preferência por usuário', () {
    test('sem escolha gravada, usa o perfil dos papéis', () async {
      final auth = _auth();
      final prefs = UiPreferences(auth);
      await prefs.init();
      await auth.login('oper@x', 'senha');

      expect(prefs.isAutomatic, isTrue);
      expect(prefs.effective, UiProfile.operator);
    });

    test('escolha manual vence o automático e fica gravada por actorId',
        () async {
      final auth = _auth();
      final prefs = UiPreferences(auth);
      await prefs.init();
      await auth.login('oper@x', 'senha');

      await prefs.setPreference(UiProfile.management);

      expect(prefs.effective, UiProfile.management);
      final stored = await SharedPreferences.getInstance();
      expect(
        stored.getString('traceagro.ui.profile.actor-oper'),
        'management',
      );
    });

    test('a escolha sobrevive ao fechamento do app', () async {
      final firstRun = _auth();
      final before = UiPreferences(firstRun);
      await before.init();
      await firstRun.login('oper@x', 'senha');
      await before.setPreference(UiProfile.field);
      before.dispose();

      // Reabertura: sessão restaurada do aparelho, nova instância.
      final reopened = _auth();
      final after = UiPreferences(reopened);
      await after.init();
      await reopened.login('oper@x', 'senha');

      expect(after.preference, UiProfile.field);
      expect(after.effective, UiProfile.field);
    });

    test('usuários diferentes no mesmo aparelho têm escolhas diferentes',
        () async {
      final auth = _auth();
      final prefs = UiPreferences(auth);
      await prefs.init();

      await auth.login('oper@x', 'senha');
      await prefs.setPreference(UiProfile.technical);
      await auth.logout();

      await auth.login('vet@x', 'senha');
      expect(prefs.actorId, 'actor-vet');
      expect(prefs.isAutomatic, isTrue,
          reason: 'a escolha do operador não pode vazar para a veterinária');
      expect(prefs.effective, UiProfile.technical);
      await prefs.setPreference(UiProfile.field);
      await auth.logout();

      await auth.login('oper@x', 'senha');
      expect(prefs.preference, UiProfile.technical);
    });

    test('voltar para Automático apaga a escolha gravada', () async {
      final auth = _auth();
      final prefs = UiPreferences(auth);
      await prefs.init();
      await auth.login('oper@x', 'senha');
      await prefs.setPreference(UiProfile.management);

      await prefs.setPreference(null);

      expect(prefs.effective, UiProfile.operator);
      final stored = await SharedPreferences.getInstance();
      expect(stored.containsKey('traceagro.ui.profile.actor-oper'), isFalse);
    });

    test('sem sessão não há escolha a gravar', () async {
      final auth = _auth();
      final prefs = UiPreferences(auth);
      await prefs.init();

      await prefs.setPreference(UiProfile.management);

      expect(prefs.actorId, isNull);
      expect(prefs.preference, isNull);
      final stored = await SharedPreferences.getInstance();
      expect(
        stored.getKeys().where((k) => k.startsWith(UiPreferences.storagePrefix)),
        isEmpty,
      );
    });

    test('preferência gravada antes de abrir o armazenamento é aplicada',
        () async {
      SharedPreferences.setMockInitialValues({
        'traceagro.ui.profile.actor-oper': 'technical',
      });
      final auth = _auth();
      final prefs = UiPreferences(auth);
      // Sessão chega antes do init (ordem do boot com sessão restaurada).
      await auth.login('oper@x', 'senha');
      await prefs.init();

      expect(prefs.effective, UiProfile.technical);
    });

    test('valor desconhecido gravado volta ao Automático', () async {
      SharedPreferences.setMockInitialValues({
        'traceagro.ui.profile.actor-oper': 'perfil-que-nao-existe',
      });
      final auth = _auth();
      final prefs = UiPreferences(auth);
      await prefs.init();
      await auth.login('oper@x', 'senha');

      expect(prefs.isAutomatic, isTrue);
      expect(prefs.effective, UiProfile.operator);
    });

    test('mudar o perfil não mexe nos papéis nem nas permissões', () async {
      final auth = _auth();
      final prefs = UiPreferences(auth);
      await prefs.init();
      await auth.login('oper@x', 'senha');
      final roles = [...auth.roles];
      final permissions = [...auth.permissions];

      await prefs.setPreference(UiProfile.management);

      expect(auth.roles, roles);
      expect(auth.permissions, permissions);
      expect(auth.canManageUsers, isFalse);
    });
  });

  group('seletor em Ajustes', () {
    testWidgets('mostra Automático, os quatro modos e o aviso de permissões',
        (tester) async {
      final auth = _auth();
      final prefs = UiPreferences(auth);
      await prefs.init();
      await auth.login('oper@x', 'senha');

      await tester.pumpWidget(_selectorApp(prefs));

      expect(find.text('Automático'), findsOneWidget);
      for (final profile in UiProfile.values) {
        expect(find.text(profile.label), findsOneWidget);
      }
      expect(find.text('Agora: Operador'), findsOneWidget);
      expect(find.textContaining('Suas permissões continuam as mesmas'),
          findsOneWidget);
    });

    testWidgets('tocar num modo troca na hora, sem reiniciar', (tester) async {
      final auth = _auth();
      final prefs = UiPreferences(auth);
      await prefs.init();
      await auth.login('oper@x', 'senha');
      await tester.pumpWidget(_selectorApp(prefs));

      expect(find.byKey(const ValueKey('probe-operator')), findsOneWidget);

      await tester.tap(find.text('Gestão'));
      await tester.pump();

      expect(prefs.effective, UiProfile.management);
      // Um widget qualquer que lê o escopo reconstrói com o novo perfil.
      expect(find.byKey(const ValueKey('probe-management')), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel(RegExp('^Gestão'))),
        matchesSemantics(
          isButton: true,
          hasTapAction: true,
          isSelected: true,
          hasSelectedState: true,
          label: 'Gestão. ${UiProfile.management.description}',
        ),
      );
    });

    testWidgets('cartões cabem em telefone pequeno com texto ampliado',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final auth = _auth();
      final prefs = UiPreferences(auth);
      await prefs.init();
      await auth.login('oper@x', 'senha');
      await tester.pumpWidget(
        _selectorApp(prefs, textScaler: const TextScaler.linear(1.6)),
      );

      expect(tester.takeException(), isNull);
    });
  });
}

AuthSession _auth() => AuthSession(
      baseUrl: 'https://base.traceagro.test',
      client: MockClient((request) async {
        final body = jsonDecode(request.body) as Map;
        final email = body['email'] as String;
        final (actor, roles) = switch (email) {
          'vet@x' => ('actor-vet', ['VETE']),
          _ => ('actor-oper', ['OPER']),
        };
        return http.Response(
          jsonEncode({
            'accessToken': 'token-$actor',
            'principal': {
              'organizationId': 'org-1',
              'actorId': actor,
              'deviceId': 'device-1',
              'propertyId': 'property-1',
              'roles': roles,
              'permissions': roles.contains('VETE')
                  ? ['health.apply', 'health.private', 'reports.export']
                  : ['field.operate'],
            },
          }),
          201,
        );
      }),
    );

Widget _selectorApp(UiPreferences prefs, {TextScaler? textScaler}) =>
    UiProfileScope(
      preferences: prefs,
      child: MaterialApp(
        theme: buildTaTheme(),
        builder: textScaler == null
            ? null
            : (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: textScaler),
                  child: child!,
                ),
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: const [UiProfileSelector(), _ProfileProbe()],
          ),
        ),
      ),
    );

class _ProfileProbe extends StatelessWidget {
  const _ProfileProbe();

  @override
  Widget build(BuildContext context) {
    final profile = UiProfileScope.profileOf(context);
    return SizedBox(key: ValueKey('probe-${profile.name}'));
  }
}
