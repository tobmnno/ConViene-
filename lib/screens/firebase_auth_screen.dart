import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/conviene_logo.dart';

String firebaseAuthError(FirebaseAuthException error) {
  switch (error.code) {
    case 'email-already-in-use':
      return 'Ya existe una cuenta con ese correo. Probá ingresar.';
    case 'invalid-email':
      return 'Ingresá un correo válido.';
    case 'weak-password':
      return 'Elegí una contraseña más segura.';
    case 'invalid-credential':
    case 'wrong-password':
    case 'user-not-found':
      return 'Correo o contraseña incorrectos.';
    case 'too-many-requests':
      return 'Demasiados intentos. Esperá un momento y reintentá.';
    case 'network-request-failed':
      return 'No hay conexión. Revisá internet y reintentá.';
    default:
      return 'No pudimos completar la operación. Reintentá.';
  }
}

class FirebaseAuthScreen extends StatefulWidget {
  const FirebaseAuthScreen({super.key, required this.auth});

  final FirebaseAuth auth;

  @override
  State<FirebaseAuthScreen> createState() => _FirebaseAuthScreenState();
}

class _FirebaseAuthScreenState extends State<FirebaseAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _register = true;
  bool _busy = false;
  bool _showPassword = false;
  String? _message;
  bool _isError = false;

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (_register) {
        final result = await widget.auth.createUserWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
        await result.user!.updateDisplayName(_username.text.trim());
        await result.user!.sendEmailVerification();
      } else {
        await widget.auth.signInWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(() {
          _isError = true;
          _message = firebaseAuthError(error);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isError = true;
          _message = 'No pudimos conectar. Reintentá.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_busy) return;
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim())) {
      setState(() {
        _isError = true;
        _message = 'Ingresá primero tu correo electrónico.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.auth.sendPasswordResetEmail(email: _email.text.trim());
      if (mounted) {
        setState(() {
          _isError = false;
          _message =
              'Si existe una cuenta, recibirás un enlace para recuperar el acceso.';
        });
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(() {
          _isError = true;
          _message = firebaseAuthError(error);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: ConvieneLogo(compact: true)),
                  const SizedBox(height: 30),
                  Text(
                    _register ? 'Creá tu cuenta' : 'Bienvenido de nuevo',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _register
                        ? 'Tu nombre de usuario aparecerá en los precios que aportes.'
                        : 'Ingresá para comparar precios y guardar tu changuito.',
                    style: TextStyle(color: AppColors.textGray),
                  ),
                  const SizedBox(height: 24),
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: true,
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Registrarme', maxLines: 1),
                        ),
                      ),
                      ButtonSegment(
                        value: false,
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Ingresar', maxLines: 1),
                        ),
                      ),
                    ],
                    selected: {_register},
                    onSelectionChanged: _busy
                        ? null
                        : (selection) => setState(() {
                            _register = selection.first;
                            _message = null;
                            _formKey.currentState?.reset();
                          }),
                  ),
                  const SizedBox(height: 20),
                  if (_register) ...[
                    TextFormField(
                      controller: _username,
                      textCapitalization: TextCapitalization.none,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de usuario',
                        prefixIcon: Icon(Icons.alternate_email),
                      ),
                      validator: (value) =>
                          RegExp(
                            r'^[A-Za-z0-9_]{3,30}$',
                          ).hasMatch(value?.trim() ?? '')
                          ? null
                          : 'Usá 3 a 30 letras, números o guion bajo.',
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                    validator: (value) =>
                        RegExp(
                          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                        ).hasMatch(value?.trim() ?? '')
                        ? null
                        : 'Ingresá un correo válido.',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    obscureText: !_showPassword,
                    autofillHints: [
                      _register
                          ? AutofillHints.newPassword
                          : AutofillHints.password,
                    ],
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        tooltip: _showPassword
                            ? 'Ocultar contraseña'
                            : 'Mostrar contraseña',
                        icon: Icon(
                          _showPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () =>
                            setState(() => _showPassword = !_showPassword),
                      ),
                    ),
                    validator: (value) => (value?.length ?? 0) >= 8
                        ? null
                        : 'Mínimo 8 caracteres.',
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  if (_register) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmation,
                      obscureText: true,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: const InputDecoration(
                        labelText: 'Repetir contraseña',
                        prefixIcon: Icon(Icons.lock_reset_outlined),
                      ),
                      validator: (value) => value == _password.text
                          ? null
                          : 'Las contraseñas no coinciden.',
                    ),
                  ],
                  if (_message != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _message!,
                      style: TextStyle(
                        color: _isError
                            ? AppColors.errorText
                            : AppColors.greenText,
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_register ? 'Crear cuenta' : 'Ingresar'),
                    ),
                  ),
                  if (!_register)
                    TextButton(
                      onPressed: _busy ? null : _resetPassword,
                      child: const Text('Olvidé mi contraseña'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class FirebaseVerificationScreen extends StatefulWidget {
  const FirebaseVerificationScreen({
    super.key,
    required this.user,
    required this.onRefresh,
    required this.onSignOut,
  });

  final User user;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onSignOut;

  @override
  State<FirebaseVerificationScreen> createState() =>
      _FirebaseVerificationScreenState();
}

class _FirebaseVerificationScreenState
    extends State<FirebaseVerificationScreen> {
  bool _busy = false;
  String? _message;
  DateTime? _lastSentAt;

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.onRefresh();
      if (mounted && !widget.user.emailVerified) {
        setState(
          () => _message =
              'Todavía no se verificó el correo. Abrí el enlace y volvé a intentar.',
        );
      }
    } catch (_) {
      if (mounted)
        setState(() => _message = 'No pudimos comprobarlo. Reintentá.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    if (_busy ||
        (_lastSentAt != null &&
            DateTime.now().difference(_lastSentAt!) <
                const Duration(minutes: 1))) {
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.user.sendEmailVerification();
      _lastSentAt = DateTime.now();
      if (mounted)
        setState(
          () => _message = 'Te enviamos un nuevo correo de verificación.',
        );
    } on FirebaseAuthException catch (error) {
      if (mounted) setState(() => _message = firebaseAuthError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: ConvieneLogo(compact: true)),
                const SizedBox(height: 28),
                Text(
                  'Verificá tu correo',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                Text(
                  'Enviamos un enlace a ${widget.user.email}. Abrilo para activar tu cuenta.',
                ),
                if (_message != null) ...[
                  const SizedBox(height: 16),
                  Text(_message!, style: TextStyle(color: AppColors.textGray)),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _refresh,
                  child: Text(
                    _busy ? 'Comprobando...' : 'Ya verifiqué mi correo',
                  ),
                ),
                TextButton(
                  onPressed: _busy ? null : _resend,
                  child: const Text('Reenviar enlace'),
                ),
                TextButton(
                  onPressed: _busy ? null : widget.onSignOut,
                  child: const Text('Usar otro correo'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class FirebaseProfileScreen extends StatefulWidget {
  const FirebaseProfileScreen({
    super.key,
    required this.initialUsername,
    required this.error,
    required this.busy,
    required this.onSave,
    required this.onRetry,
    required this.onSignOut,
  });

  final String initialUsername;
  final String error;
  final bool busy;
  final Future<void> Function(String) onSave;
  final VoidCallback onRetry;
  final Future<void> Function() onSignOut;

  @override
  State<FirebaseProfileScreen> createState() => _FirebaseProfileScreenState();
}

class _FirebaseProfileScreenState extends State<FirebaseProfileScreen> {
  late final TextEditingController _username;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _username = TextEditingController(text: widget.initialUsername);
  }

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: ConvieneLogo(compact: true)),
                  const SizedBox(height: 28),
                  Text(
                    'Terminá tu perfil',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.error,
                    style: TextStyle(color: AppColors.textGray),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _username,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de usuario',
                    ),
                    validator: (value) =>
                        RegExp(
                          r'^[A-Za-z0-9_]{3,30}$',
                        ).hasMatch(value?.trim() ?? '')
                        ? null
                        : 'Usá 3 a 30 letras, números o guion bajo.',
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: widget.busy
                        ? null
                        : () {
                            if (_formKey.currentState!.validate()) {
                              widget.onSave(_username.text);
                            }
                          },
                    child: Text(
                      widget.busy ? 'Guardando...' : 'Guardar usuario',
                    ),
                  ),
                  TextButton(
                    onPressed: widget.busy ? null : widget.onRetry,
                    child: const Text('Reintentar conexión'),
                  ),
                  TextButton(
                    onPressed: widget.busy ? null : widget.onSignOut,
                    child: const Text('Salir'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
