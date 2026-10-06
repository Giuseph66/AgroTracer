import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../core/ui_profile/shell_tabs.dart';
import '../../core/ui_profile/ui_access.dart';
import '../../core/ui_profile/ui_action.dart';
import '../../core/ui_profile/ui_profile.dart';
import '../admin/admin_screen.dart';
import '../alerts/alerts_screen.dart';
import '../areas/areas_screen.dart';
import '../birth/birth_screen.dart';
import '../read/read_screen.dart';
import '../shipment/shipment_screen.dart';
import '../vaccination/vaccination_screen.dart';
import '../weighing/weighing_screen.dart';

// Papéis por coluna do Doc 7 §3. Cada ação exige permissão do catálogo da API
// E um destes papéis (D5, Doc 20 §8): vale o mais restritivo.
const _fieldCreators = {'OPER', 'PROD', 'TECN'};
const _everyoneButPublic = {
  'OPER', 'PROD', 'TECN', 'VETE', 'CERT', 'TRAN', 'FRIG', 'AUDI', 'ADMO', 'ADMP',
};

// A tela atual mistura consultar e expedir; enquanto não separa
// (Entrega 6), só quem pode expedir a vê.
const _shipmentsAccess = UiAccess(
  permissions: {'field.operate'},
  roles: _fieldCreators,
  legacyRoles: _fieldCreators,
);

const _management = UiProfile.management;
const _field = UiProfile.field;
const _operator = UiProfile.operator;
const _technical = UiProfile.technical;

/// Ler brinco — também usado pelo botão central do shell.
final readAction = UiAction(
  id: 'read',
  label: 'Ler brinco',
  icon: Icons.sensors,
  access: const UiAccess(
    permissions: {'field.operate'},
    roles: _fieldCreators,
    legacyRoles: _fieldCreators,
  ),
  screen: (_, _) => const ReadScreen(),
  homeOrder: const {_management: 2, _field: 0, _operator: 0, _technical: 3},
  primaryIn: const {_field, _operator},
);

/// Todas as ações que podem aparecer no Início. A ordem de cada perfil segue a
/// matriz do Doc 20 §7; a autorização vem da sessão, nunca do perfil.
final homeActionCatalog = <UiAction>[
  readAction,
  UiAction(
    id: 'weighing',
    label: 'Pesagem',
    labels: const {_operator: 'Pesar'},
    icon: Icons.monitor_weight_outlined,
    // Doc 7: Pesagens "C" só para OPER e TECN. PROD tem field.operate no
    // catálogo, mas não cria pesagem até a divergência ser decidida (D5/I1).
    access: const UiAccess(
      permissions: {'field.operate'},
      roles: {'OPER', 'TECN'},
      legacyRoles: {'OPER', 'TECN'},
    ),
    screen: (_, _) => const WeighingScreen(),
    homeOrder: const {_management: 3, _field: 1, _operator: 1, _technical: 6},
    primaryIn: const {_field, _operator},
  ),
  const UiAction(
    id: 'animals',
    label: 'Animais',
    labels: {_operator: 'Ver animal'},
    icon: Icons.badge_outlined,
    // D2: não há permissão de leitura no catálogo; consulta é de todo papel
    // com vínculo, exceto a visão pública.
    access: UiAccess(roles: _everyoneButPublic),
    tab: ShellTab.animals,
    homeOrder: {_management: 0, _field: 2, _operator: 2, _technical: 2},
    primaryIn: {_management},
  ),
  UiAction(
    id: 'alerts',
    label: 'Alertas',
    icon: Icons.notifications_active_outlined,
    access: const UiAccess(roles: _everyoneButPublic),
    screen: (context, _) {
      final tabs = ShellTabs.maybeOf(context);
      return AlertsScreen(
        onOpenPending: tabs == null ? null : () => tabs.select(ShellTab.pending),
        canOpenShipments: _shipmentsAccess.allows(Services.of(context).auth),
      );
    },
    homeOrder: const {_management: 1, _field: 7, _technical: 1},
    primaryIn: const {_management, _technical},
  ),
  UiAction(
    id: 'vaccination',
    label: 'Vacinação',
    labels: const {_operator: 'Vacinar'},
    icon: Icons.vaccines_outlined,
    // OPER aplica só com delegação (Doc 7 "A"): precisa também de
    // health.apply na sessão (D4).
    access: const UiAccess(
      permissions: {'health.apply'},
      roles: {'OPER', 'TECN', 'VETE'},
      legacyRoles: {'TECN', 'VETE'},
    ),
    screen: (_, _) => const VaccinationScreen(),
    homeOrder: const {_management: 4, _field: 3, _operator: 3, _technical: 0},
    primaryIn: const {_technical},
  ),
  UiAction(
    id: 'birth',
    label: 'Nascimento',
    labels: const {_operator: 'Registrar nascimento'},
    icon: Icons.child_friendly_outlined,
    access: const UiAccess(
      permissions: {'field.operate'},
      roles: _fieldCreators,
      legacyRoles: _fieldCreators,
    ),
    screen: (_, _) => const BirthScreen(),
    homeOrder: const {_management: 5, _field: 4, _operator: 4},
  ),
  UiAction(
    id: 'paddocks',
    label: 'Piquetes',
    icon: Icons.fence_outlined,
    access: const UiAccess(
      permissions: {'field.operate'},
      roles: _fieldCreators,
      legacyRoles: _fieldCreators,
    ),
    // Perfis simples abrem na lista: mover animais sem passar pelo mapa.
    screen: (_, profile) => AreasScreen(
      startInList: profile == _operator || profile == _field,
    ),
    homeOrder: const {_management: 6, _field: 5, _operator: 5, _technical: 4},
  ),
  UiAction(
    id: 'shipments',
    label: 'Embarques',
    icon: Icons.local_shipping_outlined,
    access: _shipmentsAccess,
    screen: (_, _) => const ShipmentScreen(),
    homeOrder: const {_management: 7, _field: 6, _operator: 6},
  ),
  const UiAction(
    id: 'pending',
    label: 'Pendências',
    icon: Icons.pending_actions_outlined,
    access: UiAccess.anySession,
    tab: ShellTab.pending,
    homeOrder: {_operator: 7},
  ),
  UiAction(
    id: 'admin',
    label: 'Central de acesso',
    icon: Icons.admin_panel_settings_outlined,
    access: const UiAccess(
      permissions: {'users.manage'},
      roles: {'ADMO', 'ADMP'},
      legacyRoles: {'ADMO', 'ADMP'},
    ),
    screen: (_, _) => const AdminScreen(),
    homeOrder: const {_management: 8},
  ),
];
