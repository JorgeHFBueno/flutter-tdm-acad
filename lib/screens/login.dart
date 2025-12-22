import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '/components/my_button.dart';
import '/components/my_textfield.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  final Function()? onTap;
  LoginScreen({super.key, required this.onTap});

  @override
  State<LoginScreen> createState() {
    return LoginScreenState();
  }
}

class LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  void _showLoading() {
    // loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xffE01C2F)),
      ),
    );
  }

  void _hideLoading() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleSignIn() async {
    _showLoading();

    try {
      await _authService.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      // fecha o loading; NÃO navega — AuthScreen já troca para MenuOptions
      _hideLoading();
    } on FirebaseAuthException catch (e) {
      _hideLoading();
      if (e.code == 'invalid-credential') {
        _genericErrorMessage('Credenciais inválidas, tente novamente!');
      } else if (e.code == 'invalid-email') {
        _genericErrorMessage('Informe um email válido!');
      } else if (e.code == 'user-not-found') {
        _genericErrorMessage('Email não encontrado, efetue o registro!');
      } else if (e.code == 'wrong-password') {
        _genericErrorMessage('Senha incorreta, tente novamente!');
      } else {
        _genericErrorMessage(e.message ?? e.code);
      }
    } catch (e) {
      _hideLoading();
      _genericErrorMessage(e.toString());
    }
  }

  Future<void> _handleGoogleSignIn() async {
    // loading
    _showLoading();

    try {
      await _authService.signInWithGoogle();
      _hideLoading();
    } on AuthServiceException catch (e) {
      _hideLoading();
      _genericErrorMessage(_mapAuthServiceError(e));
    } on FirebaseAuthException catch (e) {
      _hideLoading();
      _genericErrorMessage(_mapFirebaseAuthError(e));
    } catch (e) {
      _hideLoading();
      _genericErrorMessage(e.toString());
    }
  }

  String _mapAuthServiceError(AuthServiceException error) {
    switch (error.code) {
      case 'user-cancelled':
        return 'Login cancelado pelo usuário.';
      case 'invalid-credential':
        return 'Credenciais inválidas.';
      case 'configuration-not-found':
        return 'Configuração do Google Sign-In ausente.';
      default:
        return error.message;
    }
  }

  String _mapFirebaseAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'network-request-failed':
        return 'Falha de rede. Verifique sua conexão.';
      case 'invalid-credential':
        return 'Credenciais inválidas.';
      case 'operation-not-allowed':
        return 'Configuração do Google Sign-In ausente.';
      default:
        return error.message ?? 'Falha no login com Google.';
    }
  }

  void _genericErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 243, 243, 243),
      resizeToAvoidBottomInset: true,
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 50),
                SizedBox(
                  height: 100,
                  child: ClipOval(child: Image.asset('assets/logos/logo.jpg')),
                ),
                const SizedBox(height: 10),
                Text(
                  'Olá, efetue o login para continuar. ',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 25),

                MyTextField(
                  controller: _emailController,
                  hintText: 'Email',
                  icon: const Icon(Icons.email_outlined),
                  obscureText: false,
                  capitalization: false,
                ),
                const SizedBox(height: 15),

                MyTextField(
                  controller: _passwordController,
                  hintText: 'Senha',
                  icon: const Icon(Icons.lock_outline),
                  obscureText: true,
                  capitalization: false,
                ),
                const SizedBox(height: 15),

                MyButton(
                  onPressed: _handleSignIn,
                  formKey: _formKey,
                  text: 'Logar',
                ),
                const SizedBox(height: 20),

                // continue with
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Row(
                    children: [
                      Expanded(
                        child: Divider(
                          thickness: 0.5,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 8, right: 8),
                        child: Text(
                          'OU',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          thickness: 0.5,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Google button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _handleGoogleSignIn,
                      icon: SvgPicture.asset(
                        'assets/icons/google.svg',
                        height: 22,
                      ),
                      label: const Text('Entrar com Google'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // not a member? register now
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Novo por aqui? ',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    GestureDetector(
                      onTap: widget.onTap,
                      child: const Text(
                        'Registre-se',
                        style: TextStyle(
                          color: Color(0xffE01C2F),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
