import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  NotificationService(
      {FirebaseMessaging? messaging, FirebaseFirestore? firestore})
      : _messaging = messaging ?? FirebaseMessaging.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;

  Future<void> initializeSilently() async {
    await _messaging.setAutoInitEnabled(true);
  }

  Future<String?> requestPermissionAndGetToken() async {
    final settings = await _messaging.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return null;
    }
    return _messaging.getToken();
  }

  /// Saves this device's push token in users/{uid}.fcmTokens so the report
  /// script can notify it. Native only, never blocks the UI: awaiting this in
  /// main() used to freeze app loading.
  Future<void> registerDevice(String uid) async {
    if (kIsWeb) return;
    try {
      final token = await requestPermissionAndGetToken()
          .timeout(const Duration(seconds: 20));
      if (token != null) await _saveToken(uid, token);
      _messaging.onTokenRefresh.listen(
        (token) => unawaited(_saveToken(uid, token)),
        onError: (_) {},
      );
    } catch (error) {
      debugPrint('Push nao registrado: $error');
    }
  }

  Future<void> _saveToken(String uid, String token) {
    return _firestore.collection('users').doc(uid).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
    }, SetOptions(merge: true));
  }
}
