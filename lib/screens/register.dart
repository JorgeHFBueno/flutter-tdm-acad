import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'auth.dart';
import '/components/my_button.dart';
import '/components/my_textfield.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/auth_service.dart';


class RegisterScreen extends StatefulWidget {
  final Function()? onTap;
  RegisterScreen({super.key, required this.onTap});

  @override
  State<RegisterScreen> createState() {
    return RegisterScreenState();
  }
}

class RegisterScreenState extends State<RegisterScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
  TextEditingController();

  void _showLoading() {
    // show loading circle
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xffE01C2F)),
          );
        });
  }

  void _hideLoading() {
    if (Navigator.of(context).canPop()) {
      Navigator.pop(context);
    }
  }

  void _handleSignUp() async {
    // show loading circle
    _showLoading();

    try {
      // check if both password and confirm password is same
      if (_passwordController.text == _confirmPasswordController.text) {
        UserCredential userCredential =
        await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        print('Usuário ${userCredential.user!.email} registrado!');

        // pop the loading circle
        _hideLoading();

        // save to users collection
        final CollectionReference _users =
        FirebaseFirestore.instance.collection('users');
        await _users.doc(userCredential.user!.uid).set({
          'uid': userCredential.user!.uid,
          'displayName': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'photoURL':
          'https://ui-avatars.com/api/?name=${_nameController.text}&background=E01C2F&color=fff'
        });
        // go to home screen
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AuthScreen()),
        );
      } else {
        // pop the loading circle
        _hideLoading();

        // show error password don't match
        genericErrorMessage("As senhas não correspondem!");
      }
    } on FirebaseAuthException catch (e) {
      // pop the loading circle
      _hideLoading();

      // show errors messsages
      if (e.code == 'weak-password') {
        genericErrorMessage('A senha é muito fraca, tente novamente!');
      } else if (e.code == 'invalid-email') {
        genericErrorMessage('Informe um email válido!');
      } else if (e.code == 'email-already-in-use') {
        genericErrorMessage('Email já cadastrado, efetue o login!');
      } else {
        // another error
        genericErrorMessage(e.code);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    _showLoading();

    try {
      await _authService.signInWithGoogle();
      _hideLoading();
    } on AuthServiceException catch (e) {
      _hideLoading();
      genericErrorMessage(_mapAuthServiceError(e));
    } on FirebaseAuthException catch (e) {
      _hideLoading();
      genericErrorMessage(_mapFirebaseAuthError(e));
    } catch (e) {
      _hideLoading();
      genericErrorMessage(e.toString());
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

  void genericErrorMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 243, 243, 243),
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
                  'Por favor, preenchar os seus dados para continuar. ',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 25),

                MyTextField(
                  controller: _nameController,
                  hintText: 'Nome completo',
                  icon: Icon(Icons.person_outline),
                  obscureText: false,
                  capitalization: true,
                ),
                const SizedBox(height: 15),

                MyTextField(
                  controller: _emailController,
                  hintText: 'Email',
                  icon: Icon(Icons.email_outlined),
                  obscureText: false,
                  capitalization: false,
                ),
                const SizedBox(height: 15),

                MyTextField(
                  controller: _passwordController,
                  hintText: 'Senha',
                  icon: Icon(Icons.lock_outline),
                  obscureText: true,
                  capitalization: false,
                ),
                const SizedBox(height: 15),

                MyTextField(
                  controller: _confirmPasswordController,
                  hintText: 'Confirmar senha',
                  icon: Icon(Icons.shield_outlined),
                  obscureText: true,
                  capitalization: false,
                ),
                const SizedBox(height: 15),

                MyButton(
                  onPressed: _handleSignUp,
                  formKey: _formKey,
                  text: 'Registrar',
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

                //google button
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
                    side: BorderSide(color: Colors.grey),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                    ),
              ),
                ),
                const SizedBox(height: 30),

                // already a member? login now
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Já possui uma conta? ',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    GestureDetector(
                      onTap: widget.onTap,
                      child: Text(
                        'Faça login',
                        style: TextStyle(
                            color: Color(0xffE01C2F),
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
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
