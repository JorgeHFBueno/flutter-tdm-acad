import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'user_profile_service.dart';

class AuthServiceException implements Exception {
  AuthServiceException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'AuthServiceException($code): $message';
}

class AuthService {
  AuthService({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    UserProfileService? userProfileService,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn(),
        _userProfileService = userProfileService ?? UserProfileService();

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final UserProfileService _userProfileService;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  Future<UserCredential> signInWithGoogle() async {
    GoogleSignInAccount? googleUser;
    try {
      UserCredential credential;
      if (kIsWeb) {
        final provider = GoogleAuthProvider()..addScope('email');
        credential = await _auth.signInWithPopup(provider);
      } else {
        googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          throw AuthServiceException(
            'user-cancelled',
            'Login cancelado pelo usuário.',
          );
        }
        final googleAuth = await googleUser.authentication;
        if (googleAuth.accessToken == null && googleAuth.idToken == null) {
          throw AuthServiceException(
            'invalid-credential',
            'Credenciais inválidas.',
          );
        }
        final oauthCredential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        credential = await _auth.signInWithCredential(oauthCredential);
      }

      await _userProfileService.upsertUserProfile(
        credential.user,
        provider: 'google',
      );

      return credential;
    } on FirebaseAuthException catch (e) {
      throw AuthServiceException(
        e.code,
        e.message ?? 'Falha no login com Google.',
      );
    } on PlatformException catch (e) {
      if (e.code == 'sign_in_canceled') {
        throw AuthServiceException(
          'user-cancelled',
          'Login cancelado pelo usuário.',
        );
      }
      throw AuthServiceException(
        'configuration-not-found',
        'Configuração do Google Sign-In ausente.',
      );
    } catch (e) {
      throw AuthServiceException(
        'unknown',
        'Falha inesperada no login com Google.',
      );
    } finally {
      if (!kIsWeb && googleUser == null) {
        try {
          await _googleSignIn.signOut();
        } catch (_) {}
      }
    }
  }
}
