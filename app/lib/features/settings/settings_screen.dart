import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../core/sync/sync_service.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';

/// Ajustes: o que o operador precisa conferir quando algo não vai bem —
/// qual aparelho é este, com qual servidor fala, e o que está pendente.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = Services.of(context);
    final t = Theme.of(context).textTheme;

    return SafeArea(
      child: ListenableBuilder(
        listenable: services.sync,
        builder: (context, _) {
          final sync = services.sync;
          return ListView(
            padding: const EdgeInsets.all(TaSpace.md),
            children: [
              Text('Ajustes', style: t.displayMedium),
              const SizedBox(height: TaSpace.lg),
              if (services.auth.token != null) ...[
                const SectionLabel('Sessão'),
                const SizedBox(height: TaSpace.sm),
                TaCard(
                  padding: const EdgeInsets.symmetric(horizontal: TaSpace.md),
                  child: Column(
                    children: [
                      _row(
                        context,
                        'Operador',
                        '${services.auth.identity.actorName} · ${services.auth.identity.actorId}',
                      ),
                      const Divider(),
                      _row(
                        context,
                        'Organização',
                        services.auth.identity.organizationId,
                      ),
                      const Divider(),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: () => services.auth.logout(),
                          icon: const Icon(Icons.logout),
                          label: const Text('Encerrar sessão'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: TaSpace.lg),
              ],
              const SectionLabel('Conexão'),
              const SizedBox(height: TaSpace.sm),
              TaCard(
                padding: const EdgeInsets.symmetric(horizontal: TaSpace.md),
                child: Column(
                  children: [
                    _row(context, 'Servidor', apiBaseUrl),
                    const Divider(),
                    _row(
                      context,
                      'Estado',
                      _connectivityLabel(sync.connectivity),
                    ),
                    const Divider(),
                    _row(
                      context,
                      'Última sincronização',
                      sync.lastSyncAt == null
                          ? 'ainda não sincronizou'
                          : dayHourFmt.format(sync.lastSyncAt!),
                    ),
                    const Divider(),
                    _row(
                      context,
                      'Desvio de relógio',
                      '${sync.clockSkewMs} ms em relação ao servidor',
                    ),
                  ],
                ),
              ),
              if (sync.lastError != null) ...[
                const SizedBox(height: TaSpace.sm),
                Container(
                  padding: const EdgeInsets.all(TaSpace.md),
                  decoration: BoxDecoration(
                    color: TaColors.clayBg,
                    borderRadius: BorderRadius.circular(TaRadius.md),
                  ),
                  child: Text(
                    'Último erro de envio: ${sync.lastError}',
                    style: t.bodySmall!.copyWith(color: TaColors.clay),
                  ),
                ),
              ],
              const SizedBox(height: TaSpace.lg),
              const SectionLabel('Este aparelho'),
              const SizedBox(height: TaSpace.sm),
              TaCard(
                padding: const EdgeInsets.symmetric(horizontal: TaSpace.md),
                child: Column(
                  children: [
                    _row(
                      context,
                      'Dispositivo',
                      services.auth.identity.deviceId,
                    ),
                    const Divider(),
                    _row(
                      context,
                      'Versão do app',
                      services.auth.identity.appVersion,
                    ),
                    const Divider(),
                    _row(context, 'Leitor', 'AT-880 · Bluetooth'),
                    const Divider(),
                    _row(context, 'Balança', 'AT-2 · serial'),
                  ],
                ),
              ),
              const SizedBox(height: TaSpace.md),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    services.sync.sync();
                    services.herd.refresh();
                  },
                  icon: const Icon(Icons.sync),
                  label: const Text('Sincronizar agora'),
                ),
              ),
              const SizedBox(height: TaSpace.sm),
              Text(
                'Enrolamento com chave no Keystore, MFA e revogação remota '
                'entram na Fase 2 (módulos 1 e 17 do escopo funcional).',
                style: t.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: t.bodyMedium)),
          Expanded(
            child: Text(
              value,
              style: t.labelMedium,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  String _connectivityLabel(ConnectivityState s) => switch (s) {
    ConnectivityState.online => 'conectado',
    ConnectivityState.syncing => 'enviando',
    ConnectivityState.offline => 'sem conexão — registros seguem locais',
  };
}
