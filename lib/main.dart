import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app/appearance/app_appearance_controller.dart';
import 'app/appearance/app_content_frame.dart';
import 'app/appearance/app_appearance_overlay.dart';
import 'app/appearance/app_appearance_scope.dart';
import 'app/appearance/app_theme_factory.dart';
import 'firebase_options.dart';
import 'screens/auth.dart';
import 'screens/workout_creation_screen.dart';
import 'menu2.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Inicializa Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 2) Push: registrado depois do login (menu2), sem await aqui.
  //    Análises vêm da tarefa agendada (tools/relatorio), não mais do Gemini.

  // 3) Carrega preferencias visuais locais
  final appearanceController = AppAppearanceController();
  await appearanceController.load();

  // 4) Sobe o app
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
                child: AppContentFrame(
                  child: child ?? const SizedBox.shrink(),
                ),
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
