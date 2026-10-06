import 'package:flutter/widgets.dart';

import 'ui_preferences.dart';
import 'ui_profile.dart';

/// Disponibiliza o perfil de interface para toda a árvore. Fica acima do
/// MaterialApp: trocar o modo em Ajustes reconstrói inclusive as rotas já
/// abertas e as abas mantidas vivas pelo IndexedStack do shell.
class UiProfileScope extends InheritedNotifier<UiPreferences> {
  const UiProfileScope({
    super.key,
    required UiPreferences preferences,
    required super.child,
  }) : super(notifier: preferences);

  static UiPreferences of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<UiProfileScope>();
    assert(scope != null, 'UiProfileScope não encontrado acima deste widget');
    return scope!.notifier!;
  }

  /// Perfil em uso, já resolvido (Automático vira o perfil dos papéis).
  static UiProfile profileOf(BuildContext context) => of(context).effective;
}
