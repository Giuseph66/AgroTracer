import 'package:flutter/widgets.dart';

import 'ui_action.dart';

/// Deixa o Início trocar de aba do shell (ex.: bloco "Ver animal" abre a aba
/// Animais) sem empilhar uma segunda cópia da tela.
class ShellTabs extends InheritedWidget {
  const ShellTabs({super.key, required this.select, required super.child});

  final ValueChanged<ShellTab> select;

  static ShellTabs? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellTabs>();

  @override
  bool updateShouldNotify(ShellTabs oldWidget) => false;
}
