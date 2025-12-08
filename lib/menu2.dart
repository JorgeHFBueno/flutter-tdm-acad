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



//Home, Você Sabia, Lista de locais, Chat, Rótulo de imagens, Tradução
class MenuOptions extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return MenuOptionsState();
  }
}

class MenuOptionsState extends State<MenuOptions> {
  int paginaAtual = 0;
  PageController? pc;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: pc,
        //Home, Você Sabia, Lista de locais, Chat, Rótulo de imagens, Tradução
        children: [
          Home(),
          VoceSabiaList(),
          MapLista(),
          ChatScreen(),
          ImageLabelingScreen(),
          TranslationTutorial(),
          ChatScreenAI()
        ],
        onPageChanged: setPaginaAtual,
      ), // PageView
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: paginaAtual,
        items: [
          BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: "Home"), // BottomNavigationBarItem
          BottomNavigationBarItem(
              icon: Icon(Icons.add_alert_rounded),
              label: "Você Sabia"),
          BottomNavigationBarItem(
              icon: Icon(Icons.map),
              label: "Mapa"),
          BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble),
              label: "Chat")// BottomNavigationBarItem
        ],
        onTap: (pagina) {
          pc?.animateToPage(pagina,
              duration: Duration(microseconds: 400),
              curve: Curves.ease);
        },
      ),

    );
  }

  @override
  void initState() {
    super.initState();
    pc = PageController(initialPage: paginaAtual);
  }

  setPaginaAtual(pagina) {
    setState(() {
      paginaAtual = pagina;
    });
  }
}