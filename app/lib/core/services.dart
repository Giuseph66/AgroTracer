import 'package:flutter/widgets.dart';

import '../data/api_client.dart';
import '../data/herd_repository.dart';
import 'sync/outbox.dart';
import 'sync/sync_service.dart';

/// Endereço da API. Em desenvolvimento aponta para a instância local; no
/// dispositivo real vem da configuração de ambiente do build.
const apiBaseUrl = String.fromEnvironment(
  'TRACEAGRO_API',
  defaultValue: 'http://localhost:3999',
);

/// Serviços de longa duração do app, criados uma vez e injetados na árvore.
class AppServices {
  AppServices()
      : outbox = Outbox(),
        api = ApiClient(baseUrl: apiBaseUrl) {
    herd = HerdRepository(api: api);
    sync = SyncService(outbox: outbox, baseUrl: apiBaseUrl);
  }

  final Outbox outbox;
  final ApiClient api;
  late final HerdRepository herd;
  late final SyncService sync;

  void start() {
    sync.start();
    herd.refresh();
  }

  void dispose() {
    sync.dispose();
    herd.dispose();
    api.close();
    outbox.dispose();
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
  bool updateShouldNotify(Services oldWidget) =>
      services != oldWidget.services;
}
