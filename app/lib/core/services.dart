import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/api_client.dart';
import '../data/herd_repository.dart';
import 'auth/auth_session.dart';
import 'sync/outbox.dart';
import 'sync/sync_service.dart';

/// Endereço da API.
///
/// O valor é resolvido em **tempo de compilação**: o que estiver aqui (ou no
/// `--dart-define`) fica gravado no binário, e nenhum arquivo de ambiente lido
/// depois muda isso. Por isso o default precisa ser o mesmo da API em
/// desenvolvimento — 4009, igual ao de `api/src/main.ts` e `config/dev.json`.
///
/// Para apontar para outro servidor (aparelho físico na rede da fazenda, por
/// exemplo), compile com:
///
/// ```
/// flutter run --dart-define-from-file=../config/dev.json
/// flutter run --dart-define=TRACEAGRO_API=http://192.168.0.10:4009
/// ```
const apiBaseUrl = String.fromEnvironment(
  'TRACEAGRO_API',
  defaultValue: 'http://localhost:4009',
);

/// Serviços de longa duração do app, criados uma vez e injetados na árvore.
class AppServices {
  AppServices() : outbox = Outbox(), auth = AuthSession(baseUrl: apiBaseUrl) {
    api = ApiClient(baseUrl: apiBaseUrl, tokenProvider: () => auth.token);
    herd = HerdRepository(
      api: api,
      propertyIdProvider: () => auth.identity.propertyId,
    );
    sync = SyncService(
      outbox: outbox,
      baseUrl: apiBaseUrl,
      tokenProvider: () => auth.token,
    );
  }

  final Outbox outbox;
  final AuthSession auth;
  late ApiClient api;
  late final HerdRepository herd;
  late SyncService sync;
  bool _operationalStarted = false;

  void start() {
    unawaited(_start());
  }

  Future<void> _start() async {
    await outbox.restore();
    await auth.restore();
    await auth.bootstrap();
    if (auth.isAuthenticated) await activate();
  }

  Future<void> activate() async {
    if (_operationalStarted) return;
    _operationalStarted = true;
    outbox.setIdentity(auth.identity);
    sync.start();
    await herd.restoreCache();
    await herd.refresh();
  }

  Future<bool> login(String email, String password) async {
    final ok = await auth.login(email, password);
    if (ok) await activate();
    return ok;
  }

  void dispose() {
    sync.dispose();
    herd.dispose();
    api.close();
    outbox.dispose();
    auth.dispose();
  }
}

class Services extends InheritedWidget {
  const Services({super.key, required this.services, required super.child});

  final AppServices services;

  static AppServices of(BuildContext context) {
    final found = context.dependOnInheritedWidgetOfExactType<Services>();
    assert(found != null, 'Services não encontrado acima deste widget');
    return found!.services;
  }

  @override
  bool updateShouldNotify(Services oldWidget) => services != oldWidget.services;
}
