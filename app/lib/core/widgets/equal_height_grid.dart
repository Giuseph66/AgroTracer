import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Grade vertical cujas linhas têm cartões da mesma altura. Sem rolagem
/// horizontal e sem proporção fixa: a altura acompanha o conteúdo, então texto
/// ampliado pelo aparelho não estoura o bloco.
class EqualHeightGrid extends StatelessWidget {
  const EqualHeightGrid({
    super.key,
    required this.children,
    required this.columnsFor,
    this.spacing = TaSpace.sm,
  });

  final List<Widget> children;

  /// Colunas para a largura disponível.
  final int Function(double width) columnsFor;
  final double spacing;

  /// Telefone 2, tablet 3, tela larga 4.
  static int responsiveColumns(double width) =>
      width >= 900 ? 4 : (width >= 600 ? 3 : 2);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = columnsFor(constraints.maxWidth).clamp(1, 12);
        return Column(
          children: [
            for (var i = 0; i < children.length; i += columns) ...[
              if (i > 0) SizedBox(height: spacing),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var c = 0; c < columns; c++) ...[
                      if (c > 0) SizedBox(width: spacing),
                      Expanded(
                        child: i + c < children.length
                            ? children[i + c]
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
