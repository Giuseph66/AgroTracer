import 'package:flutter/material.dart';

/// Perfil de interface: decide **como** as funções disponíveis aparecem.
///
/// Não é papel de autorização. O que o usuário pode fazer continua vindo das
/// permissões da sessão (Doc 7) e a decisão vinculante é sempre da API; um
/// perfil nunca concede ação (Doc 20 §1).
///
/// "Automático" não é um valor deste enum: é a ausência de preferência
/// gravada, resolvida pelos papéis em `defaultUiProfileFor`.
enum UiProfile {
  management(
    'Gestão',
    'Mais informações e ferramentas administrativas.',
    Icons.insights_outlined,
  ),
  field(
    'Campo',
    'Ações do dia a dia em destaque.',
    Icons.grass_outlined,
  ),
  operator(
    'Operador',
    'Botões maiores e interface mais simples.',
    Icons.back_hand_outlined,
  ),
  technical(
    'Técnico',
    'Sanidade e acompanhamento em destaque.',
    Icons.medical_services_outlined,
  );

  const UiProfile(this.label, this.description, this.icon);

  final String label;
  final String description;
  final IconData icon;

  /// Valor gravado no aparelho. Nome do enum, nunca o rótulo: o texto da tela
  /// pode mudar sem invalidar a preferência de quem já escolheu.
  String get storageValue => name;

  static UiProfile? fromStorage(String? raw) =>
      raw == null ? null : values.asNameMap()[raw];
}
