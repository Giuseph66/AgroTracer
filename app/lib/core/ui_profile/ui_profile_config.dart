import 'ui_profile.dart';

/// O que varia de um perfil para outro na apresentação. Telas leem isto em vez
/// de perguntar "qual perfil é?" espalhado pelo código.
class UiProfileConfig {
  const UiProfileConfig({
    required this.actionsTitle,
    required this.tileMinHeight,
    required this.tileIconSize,
    required this.largeTileLabels,
    required this.showTodayCard,
    required this.statusAlwaysVisible,
    required this.pendingTabLabel,
    required this.pendingScreenTitle,
    required this.readFabLabel,
  });

  /// Rótulo de seção acima da grade do Início.
  final String actionsTitle;

  /// Altura mínima do bloco; cresce com a escala de texto do aparelho.
  final double tileMinHeight;
  final double tileIconSize;
  final bool largeTileLabels;

  /// Cartão "Hoje" com números do rebanho.
  final bool showTodayCard;

  /// Estado de envio sempre no topo, mesmo com tudo enviado: quem trabalha
  /// offline precisa ver "Tudo enviado" para confiar que pode desligar.
  final bool statusAlwaysVisible;

  /// Aba da fila de envio. Para quem está no curral, a pergunta é "o que
  /// falta?", não "sincronizar".
  final String pendingTabLabel;
  final String pendingScreenTitle;
  final String readFabLabel;
}

extension UiProfileConfigs on UiProfile {
  UiProfileConfig get config => switch (this) {
    UiProfile.management => const UiProfileConfig(
      actionsTitle: 'Gestão da fazenda',
      tileMinHeight: 96,
      tileIconSize: 32,
      largeTileLabels: false,
      showTodayCard: true,
      statusAlwaysVisible: false,
      pendingTabLabel: 'Sincronizar',
      pendingScreenTitle: 'Sincronização',
      readFabLabel: 'Ler',
    ),
    UiProfile.field => const UiProfileConfig(
      actionsTitle: 'Trabalho de campo',
      tileMinHeight: 108,
      tileIconSize: 38,
      largeTileLabels: false,
      showTodayCard: false,
      statusAlwaysVisible: true,
      pendingTabLabel: 'Pendências',
      pendingScreenTitle: 'Pendências',
      readFabLabel: 'Ler brinco',
    ),
    UiProfile.operator => const UiProfileConfig(
      actionsTitle: 'O que vai fazer agora?',
      tileMinHeight: 124,
      tileIconSize: 46,
      largeTileLabels: true,
      showTodayCard: false,
      statusAlwaysVisible: true,
      pendingTabLabel: 'Pendências',
      pendingScreenTitle: 'Pendências',
      readFabLabel: 'Ler brinco',
    ),
    UiProfile.technical => const UiProfileConfig(
      actionsTitle: 'Sanidade e campo',
      tileMinHeight: 104,
      tileIconSize: 36,
      largeTileLabels: false,
      showTodayCard: true,
      statusAlwaysVisible: false,
      pendingTabLabel: 'Sincronizar',
      pendingScreenTitle: 'Sincronização',
      readFabLabel: 'Ler',
    ),
  };
}
