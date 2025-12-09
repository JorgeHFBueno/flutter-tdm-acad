import 'package:firebased/screens/chat.dart';
import 'package:flutter/material.dart';
import 'screens/home.dart';
import 'screens/vocesabia.dart';
import 'screens/mapa_list.dart';
import 'screens/chat.dart';
import 'screens/image_labeling.dart';
import 'screens/translation.dart';
import 'screens/chat_screen.dart';
import 'screens/mapa.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/workout_creation_screen.dart';
import 'screens/workout_list_screen.dart';

class Menu2 extends StatefulWidget {
  const Menu2({super.key});


  @override
  State<Menu2> createState() => _Menu2State();
}

class _Menu2State extends State<Menu2> {
  int _currentIndex = 0;
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
        title: 'Histórico',
        builder: () => const HistoryScreen(),
        icon: Icons.history,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_pages[_currentIndex].title),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  'Menu',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                  ),
                ),
              ),
            ),
            for (int i = 0; i < _pages.length; i++)
              ListTile(
                leading: Icon(_pages[i].icon),
                title: Text(_pages[i].title),
                selected: _currentIndex == i,
                onTap: () => _selectPage(i),
              ),
          ],
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages.map((page) => page.builder()).toList(),
      ),
    );
  }

  void _selectPage(int index) {
    setState(() {
      _currentIndex = index;
    });
    Navigator.of(context).pop();
  }
}
class _MenuPage {
  _MenuPage({
    required this.title,
    required this.builder,
    required this.icon,
  });

  final String title;
  final Widget Function() builder;
  final IconData icon;
}