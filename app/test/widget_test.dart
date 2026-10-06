import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:traceagro_app/core/services.dart';
import 'package:traceagro_app/features/home/home_screen.dart';
import 'package:traceagro_app/features/sync/sync_screen.dart';
import 'package:traceagro_app/domain/models.dart';

import 'support/test_session.dart';

/// As telas montam com os serviços reais, mas sem rede: é exatamente o estado
/// em que o app passa a maior parte do tempo no campo.
Widget _wrap(Widget child, AppServices services) =>
    appWith(services, Scaffold(body: child));

void main() {
  late AppServices services;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // Operador de curral recém-logado (perfil automático: Operador).
    services = await signedInServices(['OPER']);
  });
  tearDown(() => services.dispose());

  testWidgets('início mostra saudação e as ações de campo', (tester) async {
    await tester.pumpWidget(_wrap(const HomeScreen(), services));
    await tester.pump();

    expect(find.textContaining(', João'), findsOneWidget);
    expect(find.text('Ler brinco'), findsOneWidget);
    expect(find.text('Pesar'), findsOneWidget);
  });

  testWidgets('sem rede, a sincronização explica onde os dados estão',
      (tester) async {
    await tester.pumpWidget(_wrap(const SyncScreen(), services));
    await tester.pump();

    expect(find.text('Sem conexão agora'), findsOneWidget);
    expect(find.textContaining('seguros no aparelho'), findsOneWidget);
  });

  testWidgets('evento registrado aparece na fila de envio', (tester) async {
    await tester.pumpWidget(_wrap(const SyncScreen(), services));
    await tester.pump();
    expect(find.textContaining('Nada pendente'), findsOneWidget);

    services.outbox.enqueue(
      kind: EventKind.weighing,
      subjectId: 'animal-1',
      subjectLabel: 'Brinco 4127',
      payload: {'weightKg': 301.5},
    );
    // O stream do outbox entrega em microtask; um pump só não basta.
    await tester.pump(Duration.zero);
    await tester.pump();

    expect(find.text('Pesagem'), findsOneWidget);
    expect(find.text('Brinco 4127'), findsOneWidget);
    expect(find.text('Aguardando envio'), findsOneWidget);
  });
}
