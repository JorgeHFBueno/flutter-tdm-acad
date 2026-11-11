import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/machine_history_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/workout_creation_screen.dart';
import 'screens/workout_list_screen.dart';

class Menu2 extends StatefulWidget {
  const Menu2({super.key});

  @override
  State<Menu2> createState() => _Menu2State();
}

class _Menu2State extends State<Menu2> {
  int _currentIndex = 0;
  DateTime? _lastBackPressedAt;
  late final List<_MenuPage> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      _MenuPage(
        title: 'Início',
        builder: () => HomeScreen(embedInScaffold: false),
        icon: Icons.home,
      ),
      _MenuPage(
        title: 'Criar treino',
        builder: () => const WorkoutCreationScreen(embedInScaffold: false),
        icon: Icons.add,
      ),
      _MenuPage(
        title: 'Lista de treinos',
        builder: () => const WorkoutListScreen(embedInScaffold: false),
        icon: Icons.list_alt,
      ),
      _MenuPage(
        title: 'ConfiguraÃ§Ãµes',
        builder: () => const SettingsScreen(),
        icon: Icons.settings,
      ),
      _MenuPage(
        title: 'Histórico de Treino',
        builder: () => const HistoryScreen(),
        icon: Icons.history,
        group: 'Histórico',
      ),
      _MenuPage(
        title: 'Máquinas',
        builder: () => const MachinesScreen(embedInScaffold: false),
        icon: Icons.fitness_center,
        group: 'Histórico',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleSystemBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_pages[_currentIndex].title),
        ),
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                ),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    'Vanguard',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 24,
                    ),
                  ),
                ),
              ),
              for (int i = 0; i < _pages.length; i++)
                if (_pages[i].group == null)
                  ListTile(
                    leading: Icon(_pages[i].icon),
                    title: Text(_pages[i].title),
                    selected: _currentIndex == i,
                    onTap: () => _selectPage(i),
                  ),
              ExpansionTile(
                leading: const Icon(Icons.history),
                title: const Text('Histórico'),
                initiallyExpanded: _pages[_currentIndex].group == 'Histórico',
                children: [
                  for (int i = 0; i < _pages.length; i++)
                    if (_pages[i].group == 'Histórico')
                      ListTile(
                        leading: Icon(_pages[i].icon),
                        title: Text(_pages[i].title),
                        selected: _currentIndex == i,
                        onTap: () => _selectPage(i),
                      ),
                ],
              ),
            ],
          ),
        ),
        body: IndexedStack(
          index: _currentIndex,
          children: _pages.map((page) => page.builder()).toList(),
        ),
      ),
    );
  }

  void _selectPage(int index) {
    setState(() {
      _currentIndex = index;
    });
    Navigator.of(context).pop();
  }

  void _handleSystemBack() {
    final now = DateTime.now();
    final previous = _lastBackPressedAt;
    if (previous != null && now.difference(previous).inMilliseconds <= 2000) {
      SystemNavigator.pop();
      return;
    }
    _lastBackPressedAt = now;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Clique novamente para sair do app')),
      );
  }
}

class _MenuPage {
  _MenuPage({
    required this.title,
    required this.builder,
    required this.icon,
    this.group,
  });

  final String title;
  final Widget Function() builder;
  final IconData icon;
  final String? group;
}
