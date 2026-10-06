import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:traceagro_app/core/auth/auth_session.dart';
import 'package:traceagro_app/core/services.dart';
import 'package:traceagro_app/core/theme/theme.dart';
import 'package:traceagro_app/core/ui_profile/ui_profile_scope.dart';

/// Permissões que o catálogo da API (`policy.service.ts`) dá a cada papel.
const rolePermissions = <String, List<String>>{
  'OPER': ['field.operate'],
  'PROD': ['field.operate', 'reports.export', 'users.read'],
  'TECN': ['field.operate', 'health.apply'],
  'VETE': ['health.private', 'health.apply', 'reports.export'],
  'CERT': ['certification.review', 'reports.export'],
  'TRAN': ['shipment.transport'],
  'FRIG': ['slaughter.operate', 'shipment.receive'],
  'AUDI': ['audit.read', 'reports.export'],
  'ADMO': ['users.read', 'users.manage', 'devices.manage'],
  'ADMP': ['platform.manage', 'users.read', 'users.manage'],
  'PUBL': ['public.read'],
};

/// Sessão aberta como a API abriria para [roles]. [permissions] sobrescreve
/// o catálogo (ex.: lista vazia de sessão antiga, delegação extra).
Future<AuthSession> signedInSession(
  List<String> roles, {
  List<String>? permissions,
  String actorId = 'actor-1',
}) async {
  final session = AuthSession(
    baseUrl: 'https://base.traceagro.test',
    client: MockClient(
      (_) async => http.Response(
        jsonEncode({
          'accessToken': 'token-$actorId',
          'principal': {
            'organizationId': 'org-1',
            'actorId': actorId,
            'deviceId': 'device-1',
            'propertyId': 'property-1',
            'propertyName': 'Fazenda Teste',
            'name': 'João',
            'roles': roles,
            'permissions':
                permissions ??
                {for (final r in roles) ...?rolePermissions[r]}.toList(),
          },
        }),
        201,
      ),
    ),
  );
  await session.login('pessoa@fazenda.test', 'senha');
  return session;
}

/// Serviços do app com a sessão já aberta e o armazenamento de preferências
/// carregado — o estado do app logo depois do login.
Future<AppServices> signedInServices(
  List<String> roles, {
  List<String>? permissions,
}) async {
  final session = await signedInSession(roles, permissions: permissions);
  final services = AppServices(session: session);
  await services.ui.init();
  return services;
}

Widget appWith(AppServices services, Widget home, {TextScaler? textScaler}) =>
    Services(
      services: services,
      child: UiProfileScope(
        preferences: services.ui,
        child: MaterialApp(
          theme: buildTaTheme(),
          builder: textScaler == null
              ? null
              : (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: textScaler),
                  child: child!,
                ),
          home: home,
        ),
      ),
    );
