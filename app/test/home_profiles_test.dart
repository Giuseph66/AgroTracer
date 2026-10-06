import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:traceagro_app/core/ui_profile/ui_action.dart';
import 'package:traceagro_app/domain/models.dart';
import 'package:traceagro_app/core/ui_profile/ui_profile.dart';
import 'package:traceagro_app/features/home/home_actions.dart';
import 'package:traceagro_app/features/home/home_screen.dart';
import 'package:traceagro_app/main.dart';

import 'support/test_session.dart';

/// Ações que cada papel pode ver, por Doc 20 §8 (catálogo da API ∩ Doc 7).
/// É a referência do teste: se o catálogo de ações mudar, isto tem que mudar
/// junto, de propósito.
const _allowedByRole = <String, Set<String>>{
  'OPER': {'read', 'weighing', 'animals', 'alerts', 'birth', 'paddocks', 'shipments', 'pending'},
  // D5: PROD tem field.operate, mas o Doc 7 não lhe dá "C" de pesagem.
  'PROD': {'read', 'animals', 'alerts', 'birth', 'paddocks', 'shipments', 'pending'},
  'TECN': {'read', 'weighing', 'animals', 'alerts', 'vaccination', 'birth', 'paddocks', 'shipments', 'pending'},
  'VETE': {'animals', 'alerts', 'vaccination', 'pending'},
  'CERT': {'animals', 'alerts', 'pending'},
  'TRAN': {'animals', 'alerts', 'pending'},
  'FRIG': {'animals', 'alerts', 'pending'},
  'AUDI': {'animals', 'alerts', 'pending'},
  'ADMO': {'animals', 'alerts', 'admin', 'pending'},
  'ADMP': {'animals', 'alerts', 'admin', 'pending'},
  'PUBL': {'pending'},
};

Set<String> _ids(Iterable<UiAction> actions) => actions.map((a) => a.id).toSet();

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('filtro por permissão', () {
    test('nenhum perfil mostra ação que o papel não pode usar', () async {
      for (final MapEntry(key: role, value: allowed) in _allowedByRole.entries) {
        final auth = await signedInSession([role]);
        final union = <String>{};
        for (final profile in UiProfile.values) {
          final visible = _ids(homeActionsFor(homeActionCatalog, profile, auth));
          expect(visible.difference(allowed), isEmpty,
              reason: '$role no perfil ${profile.name}');
          union.addAll(visible);
        }
        // E o que é permitido aparece em algum perfil.
        expect(union, allowed, reason: role);
      }
    });

    test('OPER escolhendo Gestão não ganha administração nem vacinação',
        () async {
      final auth = await signedInSession(['OPER']);
      final visible = _ids(
        homeActionsFor(homeActionCatalog, UiProfile.management, auth),
      );
      expect(visible, isNot(contains('admin')));
      expect(visible, isNot(contains('vaccination')));
    });

    test('OPER com delegação de vacina (health.apply) passa a ver Vacinar',
        () async {
      final auth = await signedInSession(
        ['OPER'],
        permissions: ['field.operate', 'health.apply'],
      );
      expect(
        _ids(homeActionsFor(homeActionCatalog, UiProfile.operator, auth)),
        contains('vaccination'),
      );
    });

    test('sessão antiga sem lista de permissões usa os papéis', () async {
      final oper = await signedInSession(['OPER'], permissions: const []);
      expect(
        _ids(homeActionsFor(homeActionCatalog, UiProfile.operator, oper)),
        {'read', 'weighing', 'animals', 'birth', 'paddocks', 'shipments', 'pending'},
      );
      // Delegação de vacina não se presume: só quem já tem health.apply por
      // padrão no catálogo passa.
      final tecn = await signedInSession(['TECN'], permissions: const []);
      expect(
        _ids(homeActionsFor(homeActionCatalog, UiProfile.technical, tecn)),
        contains('vaccination'),
      );
      final noRole = await signedInSession(const [], permissions: const []);
      for (final profile in UiProfile.values) {
        expect(
          _ids(homeActionsFor(homeActionCatalog, profile, noRole))
              .difference({'pending'}),
          isEmpty,
        );
      }
    });

    test('no máximo dois destaques amarelos por perfil', () {
      for (final profile in UiProfile.values) {
        final primaries =
            homeActionCatalog.where((a) => a.primaryIn.contains(profile));
        expect(primaries.length, lessThanOrEqualTo(2), reason: profile.name);
      }
    });
  });

  group('Início por perfil', () {
    // Tela alta: a lista do Início só monta o que cabe, e estes testes olham
    // a página inteira.
    void tallView(WidgetTester tester) {
      tester.view.physicalSize = const Size(412, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('Operador: blocos grandes das tarefas do curral',
        (tester) async {
      tallView(tester);
      final services = await signedInServices(['OPER']);
      addTearDown(services.dispose);
      await tester.pumpWidget(appWith(services, const Scaffold(body: HomeScreen())));
      await tester.pump();

      for (final label in [
        'Ler brinco',
        'Pesar',
        'Ver animal',
        'Registrar nascimento',
        'Piquetes',
        'Embarques',
        'Pendências',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('Vacinar'), findsNothing);
      expect(find.text('Central de acesso'), findsNothing);
      // Estado de envio sempre visível, em palavras de trabalho.
      expect(find.text('Tudo enviado'), findsOneWidget);
      expect(find.textContaining('HOJE NA'), findsNothing);

      final readTile = tester.getSize(find.byKey(const ValueKey('home-action-read')));
      expect(readTile.height, greaterThanOrEqualTo(120));
    });

    testWidgets('Gestão do PROD: visão da fazenda, sem pesagem (D5)',
        (tester) async {
      tallView(tester);
      final services = await signedInServices(['PROD']);
      addTearDown(services.dispose);
      await tester.pumpWidget(appWith(services, const Scaffold(body: HomeScreen())));
      await tester.pump();

      expect(find.text('Animais'), findsOneWidget);
      expect(find.text('Alertas'), findsOneWidget);
      expect(find.text('Nascimento'), findsOneWidget);
      expect(find.text('Pesagem'), findsNothing);
      expect(find.text('Pesar'), findsNothing);
      expect(find.text('HOJE NA FAZENDA TESTE'), findsOneWidget);
    });

    testWidgets('Técnico da VETE: sanidade primeiro, sem atos de campo',
        (tester) async {
      final services = await signedInServices(['VETE']);
      addTearDown(services.dispose);
      await tester.pumpWidget(appWith(services, const Scaffold(body: HomeScreen())));
      await tester.pump();

      expect(find.text('Vacinação'), findsOneWidget);
      expect(find.text('Alertas'), findsOneWidget);
      expect(find.text('Animais'), findsOneWidget);
      expect(find.text('Ler brinco'), findsNothing);
      expect(find.text('Pesagem'), findsNothing);
      expect(find.text('Nascimento'), findsNothing);
    });

    // Regressão: "pesagens registradas hoje" contava toda pesagem ainda na
    // fila, inclusive de dias anteriores que não subiram.
    testWidgets('"hoje" só conta pesagens de hoje', (tester) async {
      tallView(tester);
      final services = await signedInServices(['PROD']);
      addTearDown(services.dispose);
      for (final label in ['Brinco 1', 'Brinco 2']) {
        services.outbox.enqueue(
          kind: EventKind.weighing,
          subjectId: label,
          subjectLabel: label,
          payload: {'weightKg': 300.0},
        );
      }
      await services.outbox.flush();
      final prefs = await SharedPreferences.getInstance();
      final saved = jsonDecode(prefs.getString('traceagro.outbox.v1')!) as Map;
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      ((saved['entries'] as List).first as Map)['envelope']['recordedAt'] =
          yesterday.toUtc().toIso8601String();
      await prefs.setString('traceagro.outbox.v1', jsonEncode(saved));
      await services.outbox.restore();

      await tester.pumpWidget(appWith(services, const Scaffold(body: HomeScreen())));
      await tester.pump();

      expect(find.text('pesagem registrada hoje'), findsOneWidget);
    });

    testWidgets('trocar o perfil muda o Início na hora', (tester) async {
      tallView(tester);
      final services = await signedInServices(['OPER']);
      addTearDown(services.dispose);
      await tester.pumpWidget(appWith(services, const Scaffold(body: HomeScreen())));
      await tester.pump();
      expect(find.text('Pesar'), findsOneWidget);

      await services.ui.setPreference(UiProfile.management);
      await tester.pump();

      expect(find.text('Pesar'), findsNothing);
      expect(find.text('Pesagem'), findsOneWidget);
      expect(find.textContaining('HOJE NA'), findsOneWidget);
      // Trocar a apresentação não liberou nada.
      expect(find.text('Central de acesso'), findsNothing);
      expect(find.text('Vacinação'), findsNothing);
    });

    testWidgets('nenhuma função depende de rolagem horizontal', (tester) async {
      final services = await signedInServices(['TECN']);
      addTearDown(services.dispose);
      for (final profile in UiProfile.values) {
        await services.ui.setPreference(profile);
        await tester.pumpWidget(appWith(services, const Scaffold(body: HomeScreen())));
        await tester.pump();
        final horizontal = find.byWidgetPredicate(
          (w) => w is Scrollable && axisDirectionIsReversed(w.axisDirection) == false
              && axisDirectionToAxis(w.axisDirection) == Axis.horizontal,
        );
        expect(horizontal, findsNothing, reason: profile.name);
      }
    });

    testWidgets('blocos são botões com nome para leitor de tela',
        (tester) async {
      final services = await signedInServices(['OPER']);
      addTearDown(services.dispose);
      await tester.pumpWidget(appWith(services, const Scaffold(body: HomeScreen())));
      await tester.pump();

      for (final action in homeActionsFor(
        homeActionCatalog,
        UiProfile.operator,
        services.auth,
      )) {
        expect(
          tester.getSemantics(find.byKey(ValueKey('home-action-${action.id}'))),
          matchesSemantics(
            isButton: true,
            hasTapAction: true,
            label: action.labelFor(UiProfile.operator),
          ),
          reason: action.id,
        );
      }
    });

    for (final size in const [
      Size(360, 640),
      Size(412, 915),
      Size(800, 1280),
      Size(1280, 800),
    ]) {
      testWidgets('cabe em ${size.width.toInt()}×${size.height.toInt()} '
          'com texto normal e ampliado', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final services = await signedInServices(['TECN']);
        addTearDown(services.dispose);

        for (final profile in UiProfile.values) {
          for (final scale in const [1.0, 1.6]) {
            await services.ui.setPreference(profile);
            await tester.pumpWidget(appWith(
              services,
              const Scaffold(body: HomeScreen()),
              textScaler: TextScaler.linear(scale),
            ));
            await tester.pump();
            expect(tester.takeException(), isNull,
                reason: '${profile.name} ×$scale');
          }
        }

        // Colunas: 2 no telefone, 3 no tablet em pé, 4 em tela larga.
        await services.ui.setPreference(UiProfile.field);
        await tester.pumpWidget(appWith(services, const Scaffold(body: HomeScreen())));
        await tester.pump();
        final tiles = homeActionsFor(
          homeActionCatalog,
          UiProfile.field,
          services.auth,
        ).map((a) => find.byKey(ValueKey('home-action-${a.id}'))).toList();
        final firstRowTop = tester.getTopLeft(tiles.first).dy;
        final perRow = tiles
            .where((f) => tester.getTopLeft(f).dy == firstRowTop)
            .length;
        final expected = size.width >= 900 ? 4 : (size.width >= 600 ? 3 : 2);
        expect(perRow, expected);
      });
    }
  });

  group('shell', () {
    testWidgets('Operador vê "Pendências" e "Ler brinco"; Gestão, termos atuais',
        (tester) async {
      final services = await signedInServices(['OPER']);
      addTearDown(services.dispose);
      await tester.pumpWidget(appWith(services, const AppShell()));
      await tester.pump();

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(FloatingActionButton),
          matching: find.text('Ler brinco'),
        ),
        findsOneWidget,
      );
      expect(find.text('Sincronizar'), findsNothing);

      await services.ui.setPreference(UiProfile.management);
      await tester.pump();
      expect(find.text('Sincronizar'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(FloatingActionButton),
          matching: find.text('Ler'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('sem permissão de leitura não há botão central',
        (tester) async {
      final services = await signedInServices(['VETE']);
      addTearDown(services.dispose);
      await tester.pumpWidget(appWith(services, const AppShell()));
      await tester.pump();

      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('bloco "Ver animal" leva à aba Animais sem empilhar tela',
        (tester) async {
      final services = await signedInServices(['OPER']);
      addTearDown(services.dispose);
      await tester.pumpWidget(appWith(services, const AppShell()));
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('home-action-animals')));
      await tester.pump();

      // O primeiro IndexedStack sob o shell é o das abas (o Scaffold tem
      // outros por dentro).
      final shellStack = find
          .descendant(
            of: find.byType(AppShell),
            matching: find.byType(IndexedStack),
          )
          .first;
      expect(tester.widget<IndexedStack>(shellStack).index,
          ShellTab.animals.index);
    });
  });
}
