import 'ui_profile.dart';

/// Ordem de avaliação do perfil automático (Doc 20 §6.1). O primeiro grupo
/// com algum papel da sessão vence: quem acumula papéis recebe a apresentação
/// do papel mais amplo, e pode trocar em Ajustes.
const _rolePriority = <(Set<String>, UiProfile)>[
  ({'ADMO', 'ADMP', 'PROD'}, UiProfile.management),
  ({'VETE'}, UiProfile.technical),
  ({'TECN'}, UiProfile.field),
  ({'OPER'}, UiProfile.operator),
  ({'AUDI', 'CERT'}, UiProfile.management),
  ({'TRAN', 'FRIG'}, UiProfile.field),
];

/// Perfil recomendado para quem ainda não escolheu um. Só organiza a tela:
/// não lê nem altera permissões.
UiProfile defaultUiProfileFor(Iterable<String> roles) {
  final held = roles.toSet();
  for (final (group, profile) in _rolePriority) {
    if (group.any(held.contains)) return profile;
  }
  return UiProfile.field;
}
