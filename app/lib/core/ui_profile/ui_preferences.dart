import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_session.dart';
import 'ui_profile.dart';
import 'ui_profile_resolver.dart';

/// Preferência de perfil de interface de quem está usando o aparelho.
///
/// Gravada por `actorId`, não por aparelho: o mesmo celular passa de mão em
/// mão no curral, e cada trabalhador encontra a tela como deixou. Acompanha a
/// sessão sozinha — trocar de conta troca a preferência sem reiniciar.
class UiPreferences extends ChangeNotifier {
  UiPreferences(this._auth) {
    _auth.addListener(_followSession);
    _followSession();
  }

  static const storagePrefix = 'traceagro.ui.profile.';
  static String storageKey(String actorId) => '$storagePrefix$actorId';

  final AuthSession _auth;
  SharedPreferences? _prefs;
  String? _actorId;
  List<String> _roles = const [];
  UiProfile? _preference;

  /// Usuário cuja preferência está carregada; nulo sem sessão.
  String? get actorId => _actorId;

  /// Escolha manual; nulo = Automático.
  UiProfile? get preference => _preference;
  bool get isAutomatic => _preference == null;

  /// O que o modo Automático escolheria para os papéis atuais.
  UiProfile get automatic => defaultUiProfileFor(_roles);

  /// Perfil em uso: a escolha manual vence; sem ela, decide pelos papéis.
  UiProfile get effective => _preference ?? automatic;

  /// Abre o armazenamento antes da primeira tela, para a preferência já estar
  /// aplicada quando o shell aparece (sem piscar o perfil automático).
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    final stored = _read(_actorId);
    if (stored != _preference) {
      _preference = stored;
      notifyListeners();
    }
  }

  /// [profile] nulo volta ao Automático e apaga a escolha gravada.
  Future<void> setPreference(UiProfile? profile) async {
    final actor = _actorId;
    if (actor == null || profile == _preference) return;
    _preference = profile;
    notifyListeners();
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    if (profile == null) {
      await prefs.remove(storageKey(actor));
    } else {
      await prefs.setString(storageKey(actor), profile.storageValue);
    }
  }

  void _followSession() {
    final authenticated = _auth.isAuthenticated;
    final actor = authenticated ? _auth.identity.actorId : null;
    final roles = authenticated ? _auth.roles : const <String>[];
    final actorChanged = actor != _actorId;
    // AuthSession avisa também em mudanças de "ocupado"/erro; só reconstrói a
    // árvore quando quem usa ou os papéis mudaram de fato.
    if (!actorChanged && listEquals(roles, _roles)) return;
    _actorId = actor;
    _roles = roles;
    if (actorChanged) _preference = _read(actor);
    notifyListeners();
  }

  UiProfile? _read(String? actor) => actor == null
      ? null
      : UiProfile.fromStorage(_prefs?.getString(storageKey(actor)));

  @override
  void dispose() {
    _auth.removeListener(_followSession);
    super.dispose();
  }
}
