import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'auth.dart';
import '/components/my_button.dart';
import '/components/my_textfield.dart';
import '/components/auth_brand_header.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  final Function()? onTap;
  const RegisterScreen({super.key, required this.onTap});

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
  bool _isLoading = false;

  Future<void> _handleSignUp() async {
    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // check if both password and confirm password is same
      if (_passwordController.text == _confirmPasswordController.text) {
        UserCredential userCredential =
            await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        debugPrint('Usuário ${userCredential.user!.email} registrado!');

        // save to users collection
        final CollectionReference users =
            FirebaseFirestore.instance.collection('users');
        await users.doc(userCredential.user!.uid).set({
          'uid': userCredential.user!.uid,
          'displayName': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'photoURL':
              'https://ui-avatars.com/api/?name=${_nameController.text}&background=E01C2F&color=fff'
        });
        if (!mounted) {
          return;
        }
        // go to home screen
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AuthScreen()),
        );
      } else {
        // show error password don't match
        genericErrorMessage("As senhas não correspondem!");
      }
    } on FirebaseAuthException catch (e) {
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
    } catch (e) {
      genericErrorMessage(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.signInWithGoogle();
    } on AuthServiceException catch (e) {
      if (e.code != 'user-cancelled') {
        genericErrorMessage(_mapAuthServiceError(e));
      }
    } on FirebaseAuthException catch (e) {
      genericErrorMessage(_mapFirebaseAuthError(e));
    } catch (e) {
      genericErrorMessage(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          SafeArea(
            child: Form(
              key: _formKey,
              child: AutofillGroup(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 32),
                              const AuthBrandHeader(
                                subtitle:
                                    'Preencha seus dados para criar a conta.',
                              ),
                              const SizedBox(height: 24),
                              MyTextField(
                                controller: _nameController,
                                hintText: 'Nome completo',
                                icon: const Icon(Icons.person_outline),
                                obscureText: false,
                                capitalization: true,
                                autofillHints: const [AutofillHints.name],
                              ),
                              const SizedBox(height: 15),
                              MyTextField(
                                controller: _emailController,
                                hintText: 'Email',
                                icon: const Icon(Icons.email_outlined),
                                obscureText: false,
                                capitalization: false,
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.email],
                              ),
                              const SizedBox(height: 15),
                              MyTextField(
                                controller: _passwordController,
                                hintText: 'Senha',
                                icon: const Icon(Icons.lock_outline),
                                obscureText: true,
                                capitalization: false,
                                autofillHints: const [
                                  AutofillHints.newPassword,
                                ],
                              ),
                              const SizedBox(height: 15),
                              MyTextField(
                                controller: _confirmPasswordController,
                                hintText: 'Confirmar senha',
                                icon: const Icon(Icons.shield_outlined),
                                obscureText: true,
                                capitalization: false,
                                autofillHints: const [
                                  AutofillHints.newPassword,
                                ],
                              ),
                              const SizedBox(height: 15),
                              MyButton(
                                onPressed: _isLoading ? null : _handleSignUp,
                                formKey: _formKey,
                                text: 'Registrar',
                              ),
                              const SizedBox(height: 20),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 25),
                                child: Row(
                                  children: [
                                    const Expanded(
                                        child: Divider(thickness: 1)),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      child: Text(
                                        'OU',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const Expanded(
                                        child: Divider(thickness: 1)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 25),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed:
                                        _isLoading ? null : _handleGoogleSignIn,
                                    icon: SvgPicture.asset(
                                      'assets/icons/google.svg',
                                      height: 22,
                                    ),
                                    label: const Text('Entrar com Google'),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size.fromHeight(52),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 30),
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    'Já possui uma conta? ',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: widget.onTap,
                                    child: const Text('Faça login'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          if (_isLoading)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black38,
                child: Center(
                  child: CircularProgressIndicator(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
