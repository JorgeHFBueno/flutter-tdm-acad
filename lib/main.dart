import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app/appearance/app_appearance_controller.dart';
import 'app/appearance/app_appearance_overlay.dart';
import 'app/appearance/app_appearance_scope.dart';
import 'app/appearance/app_theme_factory.dart';
import 'firebase_options.dart';
import 'screens/auth.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'screens/workout_creation_screen.dart';
import 'menu2.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Inicializa Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 2) Gemini so no app nativo: na web o .env nao e publicado
  //    (firebase.json ignora arquivos ".*") e a analise por IA fica oculta.
  if (!kIsWeb) {
    await dotenv.load(fileName: ".env");
    final geminiApiKey = dotenv.env['GEMINI_API_KEY'];

    if (geminiApiKey == null || geminiApiKey.isEmpty) {
      // Se não achar a chave, loga no console pra você ver
      debugPrint('GEMINI_API_KEY não encontrada no .env');
    } else {
      Gemini.init(
        apiKey: geminiApiKey,
        enableDebugging: true,
      );
    }
  }

  // 4) Push notifications
  // await _setupPushNotifications();

  // 5) Carrega preferencias visuais locais
  final appearanceController = AppAppearanceController();
  await appearanceController.load();

  // 6) Sobe o app
  runApp(MyApp(appearanceController: appearanceController));
}

/* Future<void> _setupPushNotifications() async {
  print('_setupPushNotifications (main) iniciou');
  final fcm = FirebaseMessaging.instance;
  await fcm.requestPermission();
  final token = await fcm.getToken();
  print('FCM token (main): $token');
  print('_setupPushNotifications (main) terminou');
} */

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.appearanceController,
  });

  final AppAppearanceController appearanceController;

  @override
  Widget build(BuildContext context) {
    return AppAppearanceScope(
      controller: appearanceController,
      child: AnimatedBuilder(
        animation: appearanceController,
        builder: (context, child) {
          return MaterialApp(
            title: 'Vanguard',
            theme: AppThemeFactory.build(appearanceController.mode),
            initialRoute: '/',
            builder: (context, child) {
              return AppAppearanceOverlay(
                child: child ?? const SizedBox.shrink(),
              );
            },
            routes: {
              '/': (context) => AuthScreen(),
              '/menu': (context) => const Menu2(),
              '/workout': (context) => const WorkoutCreationScreen(),
            },
          );
        },
      ),
    );
  }
}
