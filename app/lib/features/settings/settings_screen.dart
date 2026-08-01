import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../core/sync/sync_service.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../admin/admin_screen.dart';

/// Ajustes: quem está operando, se a fila está subindo, e o essencial deste
/// aparelho — sem repetir o que já aparece em outras telas.
///
/// Trocar de conta é a ação que mais importa aqui: um aparelho compartilhado
/// entre operadores precisa disso rápido, sem procurar em submenu.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = Services.of(context);
    final t = Theme.of(context).textTheme;

    return SafeArea(
      child: ListenableBuilder(
        listenable: Listenable.merge([services.sync, services.auth]),
        builder: (context, _) {
          final sync = services.sync;
          final auth = services.auth;
          final identity = auth.identity;

          return ListView(
            padding: const EdgeInsets.all(TaSpace.md),
            children: [
              Text('Ajustes', style: t.displayMedium),
              const SizedBox(height: TaSpace.lg),

              // Quem está operando + trocar de conta, sempre visível e no
              // topo: é a pergunta mais comum num aparelho compartilhado.
              TaCard(
                child: Row(
                  children: [
                    _Avatar(name: identity.actorName),
                    const SizedBox(width: TaSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(identity.actorName, style: t.titleMedium),
                          Text(
                            identity.propertyName,
                            style: t.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _confirmLogout(context, services),
                      icon: const Icon(Icons.swap_horiz),
                      tooltip: 'Trocar de conta',
                      color: TaColors.clay,
                    ),
                  ],
                ),
              ),

              if (kIsWeb && auth.canManageUsers) ...[
                const SizedBox(height: TaSpace.md),
                TaCard(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminScreen()),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: TaColors.pasture,
                          borderRadius: BorderRadius.all(TaRadius.rSm),
                        ),
                        child: const Icon(
                          Icons.admin_panel_settings_outlined,
                          color: TaColors.tagYellow,
                        ),
                      ),
                      const SizedBox(width: TaSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Central de acesso', style: t.titleMedium),
                            Text(
                              'Pessoas, perfis e bloqueios da organização.',
                              style: t.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: TaColors.inkSoft),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: TaSpace.md),

              // Conexão em uma linha: estado + quando sincronizou pela última
              // vez. Detalhe técnico só aparece se houver erro para explicar.
              TaCard(
                onTap: () {
                  services.sync.sync();
                  services.herd.refresh();
                },
                child: Row(
                  children: [
                    _ConnectivityDot(state: sync.connectivity),
                    const SizedBox(width: TaSpace.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _connectivityLabel(sync.connectivity),
                            style: t.bodyMedium!
                                .copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            sync.lastSyncAt == null
                                ? 'ainda não sincronizou'
                                : 'última sincronização às '
                                    '${hourFmt.format(sync.lastSyncAt!)}',
                            style: t.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.sync, color: TaColors.inkSoft, size: 20),
                  ],
                ),
              ),

              if (sync.lastError != null) ...[
                const SizedBox(height: TaSpace.sm),
                Container(
                  padding: const EdgeInsets.all(TaSpace.sm),
                  decoration: BoxDecoration(
                    color: TaColors.clayBg,
                    borderRadius: BorderRadius.circular(TaRadius.sm),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          size: 16, color: TaColors.clay),
                      const SizedBox(width: TaSpace.xs),
                      Expanded(
                        child: Text(
                          sync.lastError!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodySmall!.copyWith(color: TaColors.clay),
                        ),
                      ),
                    ],
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
                    _row(context, 'Dispositivo', _short(identity.deviceId)),
                    const Divider(),
                    _row(context, 'App · Servidor',
                        '${identity.appVersion} · ${_host(apiBaseUrl)}'),
                  ],
                ),
              ),

              const SizedBox(height: TaSpace.xl),
              Center(
                child: TextButton.icon(
                  onPressed: () => _confirmLogout(context, services),
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Sair e trocar de conta'),
                  style: TextButton.styleFrom(
                    foregroundColor: TaColors.clay,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmLogout(
    BuildContext context,
    AppServices services,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Trocar de conta?'),
        content: const Text(
          'Você sai da sessão atual e pode entrar com outro operador. Os '
          'registros já feitos neste aparelho continuam salvos e sobem '
          'normalmente na próxima sincronização.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: TaColors.clay,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );

    if (confirmed == true) await services.logout();
  }

  Widget _row(BuildContext context, String label, String value) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Text(label, style: t.bodyMedium)),
          Flexible(
            child: Text(
              value,
              style: t.labelSmall,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _connectivityLabel(ConnectivityState s) => switch (s) {
        ConnectivityState.online => 'Conectado',
        ConnectivityState.syncing => 'Enviando registros',
        ConnectivityState.offline => 'Sem conexão',
      };

  String _short(String id) => id.length <= 8 ? id : '${id.substring(0, 8)}…';

  String _host(String url) {
    final uri = Uri.tryParse(url);
    return uri != null && uri.host.isNotEmpty ? uri.host : url;
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        color: TaColors.tagYellow,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 18,
          color: TaColors.stamp,
        ),
      ),
    );
  }
}

class _ConnectivityDot extends StatelessWidget {
  const _ConnectivityDot({required this.state});
  final ConnectivityState state;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      ConnectivityState.online => TaColors.sage,
      ConnectivityState.syncing => TaColors.sky,
      ConnectivityState.offline => TaColors.tagYellowDeep,
    };
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
