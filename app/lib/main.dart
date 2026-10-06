import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/services.dart';
import 'core/theme/theme.dart';
import 'core/theme/tokens.dart';
import 'core/ui_profile/shell_tabs.dart';
import 'core/ui_profile/ui_action.dart';
import 'core/ui_profile/ui_profile_config.dart';
import 'core/ui_profile/ui_profile_scope.dart';
import 'features/auth/login_screen.dart';
import 'features/animals/animals_screen.dart';
import 'features/home/home_actions.dart';
import 'features/home/home_screen.dart';
import 'features/read/read_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/sync/sync_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  runApp(const SoberanoApp());
}

class SoberanoApp extends StatefulWidget {
  const SoberanoApp({super.key});

  @override
  State<SoberanoApp> createState() => _SoberanoAppState();
}

class _SoberanoAppState extends State<SoberanoApp> {
  late final AppServices services;

  @override
  void initState() {
    super.initState();
    services = AppServices()..start();
  }

  @override
  void dispose() {
    services.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Services(
      services: services,
      child: UiProfileScope(
        preferences: services.ui,
        child: MaterialApp(
          title: 'Soberano',
          debugShowCheckedModeBanner: false,
          theme: buildTaTheme(),
          home: const AuthGate(),
        ),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Services.of(context).auth;
    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) {
        if (!auth.initialized) {
          return const Scaffold(
            backgroundColor: TaColors.pasture,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image(
                    image: AssetImage('assets/branding/mark.png'),
                    width: 96,
                    height: 96,
                  ),
                  SizedBox(height: TaSpace.lg),
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: TaColors.tagYellow,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        if (!auth.isAuthenticated) {
          return const LoginScreen();
        }
        return const AppShell();
      },
    );
  }
}

/// Navegação de campo: 4 destinos + botão central "Ler" — o gesto mais
/// frequente do curral tem o maior alvo da interface.
///
/// A estrutura é a mesma em todo perfil (Doc 20 §9); mudam os rótulos e o
/// botão central só aparece para quem pode ler brinco.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;

  static const _screens = [
    HomeScreen(),
    AnimalsScreen(),
    SyncScreen(),
    SettingsScreen(),
  ];

  void _select(ShellTab tab) => setState(() => index = tab.index);

  @override
  Widget build(BuildContext context) {
    final services = Services.of(context);
    final outbox = services.outbox;
    final config = UiProfileScope.profileOf(context).config;
    final canRead = readAction.access.allows(services.auth);

    return ShellTabs(
      select: _select,
      child: Scaffold(
        body: IndexedStack(index: index, children: _screens),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: !canRead
            ? null
            : Semantics(
                button: true,
                label: readAction.label,
                excludeSemantics: true,
                onTap: _openRead,
                child: SizedBox(
                  width: 76,
                  height: 76,
                  child: FloatingActionButton(
                    backgroundColor: TaColors.tagYellow,
                    foregroundColor: TaColors.stamp,
                    shape: const CircleBorder(
                      side: BorderSide(color: TaColors.tagYellowDeep, width: 2),
                    ),
                    onPressed: _openRead,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.sensors, size: 28),
                        Text(
                          config.readFabLabel,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11,
                            height: 1.1,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        bottomNavigationBar: StreamBuilder<void>(
          stream: outbox.changes,
          builder: (context, _) => BottomAppBar(
            color: TaColors.pasture,
            shape: canRead ? const CircularNotchedRectangle() : null,
            notchMargin: 8,
            height: 68,
            padding: EdgeInsets.zero,
            child: Row(
              children: [
                _navItem(ShellTab.home, Icons.home_outlined, Icons.home, 'Início'),
                _navItem(
                  ShellTab.animals,
                  Icons.badge_outlined,
                  Icons.badge,
                  'Animais',
                ),
                if (canRead) const SizedBox(width: 76), // vão do FAB
                _navItem(
                  ShellTab.pending,
                  Icons.pending_actions_outlined,
                  Icons.pending_actions,
                  config.pendingTabLabel,
                  badgeCount: outbox.conflictCount,
                ),
                _navItem(
                  ShellTab.settings,
                  Icons.settings_outlined,
                  Icons.settings,
                  'Ajustes',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openRead() => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const ReadScreen()));

  Widget _navItem(
    ShellTab tab,
    IconData icon,
    IconData active,
    String label, {
    int badgeCount = 0,
  }) {
    final selected = index == tab.index;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          onTap: () => _select(tab),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Badge(
                isLabelVisible: badgeCount > 0,
                backgroundColor: TaColors.clay,
                label: Text('$badgeCount'),
                child: Icon(
                  selected ? active : icon,
                  color: selected ? TaColors.tagYellow : TaColors.paperInkSoft,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? TaColors.tagYellow : TaColors.paperInkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
