import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traceagro_app/core/services.dart';
import 'package:traceagro_app/core/theme/theme.dart';
import 'package:traceagro_app/features/home/home_screen.dart';
import 'package:traceagro_app/features/sync/sync_screen.dart';
import 'package:traceagro_app/domain/models.dart';

/// As telas montam com os serviços reais, mas sem rede: é exatamente o estado
/// em que o app passa a maior parte do tempo no campo.
Widget _wrap(Widget child, AppServices services) => Services(
      services: services,
      child: MaterialApp(theme: buildTaTheme(), home: Scaffold(body: child)),
    );

void main() {
  late AppServices services;

  setUp(() => services = AppServices());
  tearDown(() => services.dispose());

  testWidgets('início mostra saudação e as ações de campo', (tester) async {
    await tester.pumpWidget(_wrap(const HomeScreen(), services));
    await tester.pump();

    expect(find.textContaining('Bom dia'), findsOneWidget);
    expect(find.text('Ler animal'), findsOneWidget);
    expect(find.text('Pesagem'), findsOneWidget);
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
