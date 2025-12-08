import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/auth.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'screens/workout_creation_screen.dart';
import 'menu2.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Carrega o .env
  await dotenv.load(fileName: ".env");

  // 2) Inicializa Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 3) Lê a chave do Gemini do .env
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

  // 4) Push notifications
  await _setupPushNotifications();

  // 5) Sobe o app
  runApp(const MyApp());
}

Future<void> _setupPushNotifications() async {
  print('_setupPushNotifications (main) iniciou');
  final fcm = FirebaseMessaging.instance;
  await fcm.requestPermission();
  final token = await fcm.getToken();
  print('FCM token (main): $token');
  print('_setupPushNotifications (main) terminou');
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      initialRoute: '/',
      routes: {
        '/': (context) => AuthScreen(),
        '/menu': (context) => const Menu2(),
        '/workout': (context) => const WorkoutCreationScreen(),
      },
    );
  }
}
