import '../auth/auth_session.dart';

/// Quem pode ver uma ação na tela. Espelho de UX da autorização: a decisão
/// vinculante continua na API (Doc 7 §5).
///
/// D5 (Doc 20 §8): a ação só aparece quando as duas fontes concordam — alguma
/// permissão do catálogo da API **e** algum papel que o Doc 7 autoriza. Em
/// conflito vale o mais restritivo; uma permissão ampla como `field.operate`
/// não autoriza sozinha todo ato de campo.
class UiAccess {
  const UiAccess({
    this.permissions = const {},
    this.roles = const {},
    this.legacyRoles = const {},
  });

  /// Qualquer sessão aberta.
  static const anySession = UiAccess();

  /// Basta uma delas (catálogo de `policy.service.ts`).
  final Set<String> permissions;

  /// Basta um deles (colunas do Doc 7 §3).
  final Set<String> roles;

  /// Sessão gravada antes do RBAC atômico chega sem lista de permissões. Só
  /// estes papéis passam nela: os que já recebem [permissions] por padrão no
  /// catálogo da API. Vazio = a ação não aparece nessa sessão. Não usar
  /// [roles] aqui: OPER está em Vacinação por delegação, sem `health.apply`.
  final Set<String> legacyRoles;

  bool allows(AuthSession auth) {
    if (!auth.isAuthenticated) return false;
    if (roles.isNotEmpty && !auth.hasAnyRole(roles)) return false;
    if (permissions.isEmpty) return true;
    if (auth.permissions.isEmpty) return auth.hasAnyRole(legacyRoles);
    return auth.canAny(permissions);
  }
}
