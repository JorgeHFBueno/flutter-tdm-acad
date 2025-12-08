import 'package:flutter/material.dart';
import 'screens/home.dart';
import 'screens/vocesabia.dart';
import 'screens/mapa_list.dart';
import 'screens/chat.dart';
import 'screens/image_labeling.dart';
import 'screens/translation.dart';
import 'screens/chat_screen.dart';
import 'screens/mapa.dart';



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
  void initState() {
    super.initState();
    pc = PageController(initialPage: paginaAtual);
  }

  void setPaginaAtual(int pagina) {
    setState(() {
      paginaAtual = pagina;
    });
  }

  void _irParaPagina(int pagina) {
    pc?.animateToPage(
      pagina,
      duration: const Duration(milliseconds: 400),
      curve: Curves.ease,
    );
    setPaginaAtual(pagina);

    // Fecha o Drawer conforme exemplo oficial (Navigator.pop) :contentReference[oaicite:2]{index=2}
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu App'),
      ),

      // MENU SANDUÍCHE
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero, // recomendado pela doc :contentReference[oaicite:3]{index=3}
          children: <Widget>[
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(
                'Menu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              selected: paginaAtual == 0,
              onTap: () => _irParaPagina(0),
            ),
            ListTile(
              leading: const Icon(Icons.add_alert_rounded),
              title: const Text('Você Sabia'),
              selected: paginaAtual == 1,
              onTap: () => _irParaPagina(1),
            ),
            ListTile(
              leading: const Icon(Icons.list),
              title: const Text('Mapa Lista'),
              selected: paginaAtual == 2,
              onTap: () => _irParaPagina(2),
            ),
            ListTile(
              leading: const Icon(Icons.chat),
              title: const Text('Chat'),
              selected: paginaAtual == 3,
              onTap: () => _irParaPagina(3),
            ),
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Image Labeling'),
              selected: paginaAtual == 4,
              onTap: () => _irParaPagina(4),
            ),
            ListTile(
              leading: const Icon(Icons.translate),
              title: const Text('Tradução'),
              selected: paginaAtual == 5,
              onTap: () => _irParaPagina(5),
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble),
              title: const Text('Chat AI'),
              selected: paginaAtual == 6,
              onTap: () => _irParaPagina(6),
            ),
          ],
        ),
      ),

      body: PageView(
        controller: pc,
        onPageChanged: setPaginaAtual,
        children: [
          Home(),                // 0
          VoceSabiaList(),       // 1
          MapLista(),            // 2
          ChatScreen(),          // 3 (nova tela de chat)
          ImageLabelingScreen(), // 4
          TranslationTutorial(), // 5
          ChatScreenAI(),        // 6 (chat antigo ou outro fluxo)
        ],
      ),
    );
  }
}
