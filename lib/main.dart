import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/auth.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'screens/workout_creation_screen.dart';

const apiKey = 'AIzaSyCUCBtkXf_GPGwQUGprO3URA1c2lk918RM';
void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform
  );
  Gemini.init(apiKey: apiKey, enableDebugging: true);

  await _setupPushNotifications();
  runApp(const MyApp());
}

Future<void> _setupPushNotifications() async{
  print('_setupPushNotifications (main) iniciou');
  final fcm = FirebaseMessaging.instance;
  await fcm.requestPermission();
  final token = await fcm.getToken();
  print ('FCM token (main): $token');
  print ('_setupPushNotifications (main) terminou');
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
        '/workout': (context) => const WorkoutCreationScreen(),
      },
    );
  }
}
