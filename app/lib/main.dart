import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/services.dart';
import 'core/theme/theme.dart';
import 'core/theme/tokens.dart';
import 'features/auth/login_screen.dart';
import 'features/animals/animals_screen.dart';
import 'features/home/home_screen.dart';
import 'features/read/read_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/sync/sync_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  runApp(const TraceAgroApp());
}

class TraceAgroApp extends StatefulWidget {
  const TraceAgroApp({super.key});

  @override
  State<TraceAgroApp> createState() => _TraceAgroAppState();
}

class _TraceAgroAppState extends State<TraceAgroApp> {
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
      child: MaterialApp(
        title: 'TraceAgro',
        debugShowCheckedModeBanner: false,
        theme: buildTaTheme(),
        home: const AuthGate(),
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

  @override
  Widget build(BuildContext context) {
    final outbox = Services.of(context).outbox;

    return Scaffold(
      body: IndexedStack(index: index, children: _screens),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: SizedBox(
        width: 72,
        height: 72,
        child: FloatingActionButton(
          backgroundColor: TaColors.tagYellow,
          foregroundColor: TaColors.stamp,
          shape: const CircleBorder(
              side: BorderSide(color: TaColors.tagYellowDeep, width: 2)),
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const ReadScreen())),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.sensors, size: 28),
              Text('Ler',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
      bottomNavigationBar: StreamBuilder<void>(
        stream: outbox.changes,
        builder: (context, _) => BottomAppBar(
          color: TaColors.pasture,
          shape: const CircularNotchedRectangle(),
          notchMargin: 8,
          height: 68,
          padding: EdgeInsets.zero,
          child: Row(
            children: [
              _navItem(0, Icons.home_outlined, Icons.home, 'Início'),
              _navItem(1, Icons.badge_outlined, Icons.badge, 'Animais'),
              const SizedBox(width: 72), // vão do FAB
              _navItem(2, Icons.sync_outlined, Icons.sync, 'Sincronizar',
                  badgeCount: outbox.conflictCount),
              _navItem(3, Icons.settings_outlined, Icons.settings, 'Ajustes'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int i, IconData icon, IconData active, String label,
      {int badgeCount = 0}) {
    final selected = index == i;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => index = i),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Badge(
              isLabelVisible: badgeCount > 0,
              backgroundColor: TaColors.clay,
              label: Text('$badgeCount'),
              child: Icon(selected ? active : icon,
                  color:
                      selected ? TaColors.tagYellow : TaColors.paperInkSoft),
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
    );
  }
}
