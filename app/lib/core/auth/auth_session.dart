import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../sync/event_envelope.dart';

enum AuthFeedbackKind { connection, credentials, service }

class AuthSession extends ChangeNotifier {
  AuthSession({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;
  static const _tokenKey = 'traceagro.auth.token';
  static const _identityKey = 'traceagro.auth.identity';

  String? accessToken;
  EventIdentity identity = DevIdentity.defaultIdentity;
  String? email;
  List<String> roles = const [];
  List<String> permissions = const [];
  bool initialized = false;
  bool busy = false;
  String? error;
  AuthFeedbackKind? feedbackKind;

  bool get requiresLogin => true;
  bool get isAuthenticated => accessToken != null && _tokenIsUsable(accessToken!);
  String? get token => accessToken;
  bool can(String permission) => permissions.contains(permission);

  /// Perfis antigos podem estar persistidos sem a lista de permissões que foi
  /// acrescentada ao RBAC. Eles só liberam a entrada visual; a API continua
  /// autorizando cada operação administrativa no servidor.
  bool get canManageUsers =>
      can('users.manage') || roles.contains('ADMO') || roles.contains('ADMP');

  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      accessToken = prefs.getString(_tokenKey);
      final raw = prefs.getString(_identityKey);
      if (raw != null) _applyPrincipal(jsonDecode(raw) as Map);
      if (accessToken != null && !_tokenIsUsable(accessToken!)) {
        await logout(notify: false);
      }
    } catch (_) {
      accessToken = null;
      identity = DevIdentity.defaultIdentity;
    }
  }

  Future<void> bootstrap() async {
    busy = true;
    error = null;
    feedbackKind = null;
    notifyListeners();
    try {
      final res = await _client
          .get(Uri.parse('$baseUrl/v1/auth/config'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        throw _AuthRequestException(res.statusCode, res.body);
      }
      if (accessToken != null) {
        final me = await _client.get(
          Uri.parse('$baseUrl/v1/auth/me'),
          headers: {'authorization': 'Bearer $accessToken'},
        );
        if (me.statusCode == 200) {
          _applyPrincipal((jsonDecode(me.body) as Map)['data'] as Map);
          await _persist();
        } else if (me.statusCode == 401 || me.statusCode == 403) {
          await logout(notify: false);
        } else {
          throw _AuthRequestException(me.statusCode, me.body);
        }
      }
      error = null;
    } catch (err) {
      // Sem uma sessão local não há identidade segura para operar offline.
      // Uma sessão já persistida continua válida até expirar/ser revogada no
      // próximo contato com a API.
      final feedback = _friendlyFeedback(err);
      error = feedback.message;
      feedbackKind = feedback.kind;
    } finally {
      initialized = true;
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    busy = true;
    error = null;
    feedbackKind = null;
    notifyListeners();
    try {
      final res = await _client
          .post(
            Uri.parse('$baseUrl/v1/auth/dev-login'),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 201 && res.statusCode != 200) {
        throw _AuthRequestException(res.statusCode, res.body);
      }
      final body = jsonDecode(res.body) as Map;
      accessToken = body['accessToken'] as String;
      _applyPrincipal(body['principal'] as Map);
      await _persist();
      return true;
    } catch (err) {
      final feedback = _friendlyFeedback(err);
      error = feedback.message;
      feedbackKind = feedback.kind;
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> logout({bool notify = true}) async {
    accessToken = null;
    identity = DevIdentity.defaultIdentity;
    email = null;
    roles = const [];
    permissions = const [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_identityKey);
    if (notify) notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    if (accessToken != null) await prefs.setString(_tokenKey, accessToken!);
    await prefs.setString(
      _identityKey,
      jsonEncode({
        'organizationId': identity.organizationId,
        'actorId': identity.actorId,
        'deviceId': identity.deviceId,
        'propertyId': identity.propertyId,
        'appVersion': identity.appVersion,
        'actorName': identity.actorName,
        'propertyName': identity.propertyName,
        'email': email,
        'roles': roles,
        'permissions': permissions,
      }),
    );
  }

  void _applyPrincipal(Map raw) {
    identity = _identityFrom(raw);
    email = raw['email'] as String?;
    roles = _stringList(raw['roles']);
    permissions = _stringList(raw['permissions']);
  }

  EventIdentity _identityFrom(Map raw) => EventIdentity(
    organizationId: raw['organizationId'] as String,
    actorId: raw['actorId'] as String,
    deviceId: raw['deviceId'] as String,
    propertyId: raw['propertyId'] as String,
    appVersion: (raw['appVersion'] as String?) ?? DevIdentity.appVersion,
    actorName:
        (raw['name'] as String?) ?? (raw['actorName'] as String?) ?? 'João P.',
    propertyName: (raw['propertyName'] as String?) ?? 'Fazenda Santa Rita',
  );

  List<String> _stringList(Object? value) => value is List
      ? value.whereType<String>().toList(growable: false)
      : const [];

  bool _tokenIsUsable(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final claims = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map;
      final expiresAt = claims['exp'];
      return expiresAt is num &&
          expiresAt * 1000 > DateTime.now().millisecondsSinceEpoch;
    } catch (_) {
      return false;
    }
  }

  _AuthFeedback _friendlyFeedback(Object err) {
    if (err is _AuthRequestException) {
      return switch (err.status) {
        400 || 401 || 403 => const _AuthFeedback(
          AuthFeedbackKind.credentials,
          'E-mail ou senha não conferem. Revise os dados e tente de novo.',
        ),
        429 => const _AuthFeedback(
          AuthFeedbackKind.service,
          'Foram muitas tentativas. Aguarde um instante antes de entrar.',
        ),
        >= 500 => const _AuthFeedback(
          AuthFeedbackKind.service,
          'A base de campo está indisponível agora. Tente novamente em alguns minutos.',
        ),
        _ => const _AuthFeedback(
          AuthFeedbackKind.service,
          'Não foi possível validar seu acesso agora. Tente novamente.',
        ),
      };
    }
    if (err is TimeoutException) {
      return const _AuthFeedback(
        AuthFeedbackKind.connection,
        'A base demorou para responder. Confira o sinal e tente novamente.',
      );
    }
    final details = err.toString().toLowerCase();
    if (details.contains('clientexception') ||
        details.contains('failed to fetch') ||
        details.contains('socketexception') ||
        details.contains('connection refused') ||
        details.contains('failed host lookup')) {
      return const _AuthFeedback(
        AuthFeedbackKind.connection,
        'Não foi possível alcançar a base de campo. Confira a conexão e tente novamente.',
      );
    }
    return const _AuthFeedback(
      AuthFeedbackKind.service,
      'Não foi possível concluir o acesso agora. Tente novamente.',
    );
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}

class _AuthRequestException implements Exception {
  const _AuthRequestException(this.status, this.body);

  final int status;
  final String body;
}

class _AuthFeedback {
  const _AuthFeedback(this.kind, this.message);

  final AuthFeedbackKind kind;
  final String message;
}
