import 'package:flutter/widgets.dart';

import '../auth/auth_session.dart';
import 'ui_access.dart';
import 'ui_profile.dart';

/// Abas fixas do shell.
enum ShellTab { home, animals, pending, settings }

/// Uma ação do app descrita como dado: o Início de cada perfil é montado a
/// partir de uma lista destas, sem uma tela por perfil (Doc 20 §9).
class UiAction {
  const UiAction({
    required this.id,
    required this.label,
    required this.icon,
    required this.access,
    this.labels = const {},
    this.screen,
    this.tab,
    this.homeOrder = const {},
    this.primaryIn = const {},
  }) : assert((screen == null) != (tab == null), 'tela ou aba, nunca ambos');

  final String id;
  final String label;

  /// Rótulo próprio de um perfil ("Pesar" no Operador).
  final Map<UiProfile, String> labels;
  final IconData icon;
  final UiAccess access;

  /// Tela empilhada ao tocar. Recebe o contexto de quem abriu (para atalhos
  /// do shell) e o perfil, para abrir no modo certo.
  final Widget Function(BuildContext context, UiProfile profile)? screen;

  /// Ou troca de aba no shell.
  final ShellTab? tab;

  /// Posição no Início de cada perfil; perfil ausente = não aparece lá.
  final Map<UiProfile, int> homeOrder;

  /// Destaque amarelo — no máximo dois por perfil ("uma voz", AGENTS §2.2).
  final Set<UiProfile> primaryIn;

  String labelFor(UiProfile profile) => labels[profile] ?? label;
}

/// Ações do Início do perfil, na ordem dele, já filtradas pela autorização
/// real. O perfil escolhe e ordena; nunca acrescenta o que a sessão não pode.
List<UiAction> homeActionsFor(
  Iterable<UiAction> catalog,
  UiProfile profile,
  AuthSession auth,
) {
  final visible = catalog
      .where((a) => a.homeOrder.containsKey(profile) && a.access.allows(auth))
      .toList();
  visible.sort((a, b) => a.homeOrder[profile]!.compareTo(b.homeOrder[profile]!));
  return visible;
}
