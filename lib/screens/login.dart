import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '/components/my_button.dart';
import '/components/my_textfield.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  final Function()? onTap;
  final AuthService? authService;

  const LoginScreen({
    super.key,
    required this.onTap,
    this.authService,
  });

  @override
  State<LoginScreen> createState() {
    return LoginScreenState();
  }
}

class LoginScreenState extends State<LoginScreen> {
  AuthService? _authService;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  AuthService get _auth =>
      widget.authService ?? (_authService ??= AuthService());

  Future<void> _handleSignIn() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      await _auth.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-credential') {
        _genericErrorMessage('Credenciais invalidas, tente novamente!');
      } else if (e.code == 'invalid-email') {
        _genericErrorMessage('Informe um email valido!');
      } else if (e.code == 'user-not-found') {
        _genericErrorMessage('Email nao encontrado, efetue o registro!');
      } else if (e.code == 'wrong-password') {
        _genericErrorMessage('Senha incorreta, tente novamente!');
      } else {
        _genericErrorMessage(e.message ?? e.code);
      }
    } catch (e) {
      _genericErrorMessage(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await _auth.signInWithGoogle();
    } on AuthServiceException catch (e) {
      if (e.code != 'user-cancelled') {
        _genericErrorMessage(_mapAuthServiceError(e));
      }
    } on FirebaseAuthException catch (e) {
      _genericErrorMessage(_mapFirebaseAuthError(e));
    } catch (e) {
      _genericErrorMessage(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _mapAuthServiceError(AuthServiceException error) {
    switch (error.code) {
      case 'user-cancelled':
        return 'Login cancelado pelo usuario.';
      case 'invalid-credential':
        return 'Credenciais invalidas.';
      case 'configuration-not-found':
        return 'Configuracao do Google Sign-In ausente.';
      default:
        return error.message;
    }
  }

  String _mapFirebaseAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'network-request-failed':
        return 'Falha de rede. Verifique sua conexao.';
      case 'invalid-credential':
        return 'Credenciais invalidas.';
      case 'operation-not-allowed':
        return 'Configuracao do Google Sign-In ausente.';
      default:
        return error.message ?? 'Falha no login com Google.';
    }
  }

  void _genericErrorMessage(String message) {
    if (!mounted) return;
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
                              Container(
                                width: 116,
                                height: 116,
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: theme.colorScheme.primary,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.18),
                                      blurRadius: 18,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: Image.asset(
                                    'assets/logos/patch_vanguard.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                'VANGUARD',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 25),
                                child: Text(
                                  'Ola, efetue o login para continuar.',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
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
                                autofillHints: const [AutofillHints.password],
                              ),
                              const SizedBox(height: 15),
                              MyButton(
                                onPressed: _isLoading ? null : _handleSignIn,
                                formKey: _formKey,
                                text: 'Entrar',
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
                                    'Novo por aqui? ',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: widget.onTap,
                                    child: const Text('Registre-se'),
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
