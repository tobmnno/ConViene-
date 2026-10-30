import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';
import '../widgets/conviene_logo.dart';

class SupabaseSetupScreen extends StatelessWidget {
  const SupabaseSetupScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ConvieneLogo(compact: true),
                const SizedBox(height: 28),
                const Icon(Icons.cloud_off_outlined, size: 42),
                const SizedBox(height: 14),
                Text(
                  'Falta conectar la base de datos',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Esta version requiere Supabase para iniciar sesion y mostrar aportes. Configura SUPABASE_URL y SUPABASE_PUBLISHABLE_KEY al ejecutar Flutter.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.client});

  final SupabaseClient client;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class PasswordRecoveryScreen extends StatefulWidget {
  const PasswordRecoveryScreen({
    super.key,
    required this.client,
    required this.onCompleted,
    required this.onCancel,
  });

  final SupabaseClient client;
  final VoidCallback onCompleted;
  final VoidCallback onCancel;

  @override
  State<PasswordRecoveryScreen> createState() => _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends State<PasswordRecoveryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.client.auth.updateUser(
        UserAttributes(password: _password.text),
      );
      if (mounted) widget.onCompleted();
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo actualizar la contraseña. Reintenta.',
        );
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
                  const SizedBox(height: 28),
                  Text(
                    'Nueva contraseña',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Elegí una contraseña para volver a entrar a tu cuenta.',
                    style: TextStyle(color: AppColors.textGray),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: const InputDecoration(
                      labelText: 'Nueva contraseña',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (value) => (value?.length ?? 0) >= 8
                        ? null
                        : 'Minimo 8 caracteres.',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmation,
                    obscureText: true,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: const InputDecoration(
                      labelText: 'Repetir contraseña',
                      prefixIcon: Icon(Icons.lock_reset_outlined),
                    ),
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'Repetí la contraseña.';
                      }
                      return value == _password.text
                          ? null
                          : 'Las contraseñas no coinciden.';
                    },
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(_error!, style: TextStyle(color: AppColors.errorText)),
                  ],
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: Text(_busy ? 'Guardando...' : 'Guardar contraseña'),
                  ),
                  TextButton(
                    onPressed: _busy ? null : widget.onCancel,
                    child: const Text('Cancelar'),
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

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = true;
  bool _busy = false;
  bool _showPassword = false;
  String? _message;
  bool _isError = false;

  String _authMessage(AuthException error) {
    final message = error.message.toLowerCase();
    if (message.contains('email address not authorized')) {
      return 'Por ahora solo pueden registrarse correos del equipo. Falta configurar el servicio de correo para abrir el registro a todos.';
    }
    if (message.contains('email not confirmed')) {
      return 'Confirma tu correo con el enlace que recibiste antes de ingresar.';
    }
    if (message.contains('invalid login credentials')) {
      return 'Correo o contraseña incorrectos.';
    }
    if (message.contains('user already registered')) {
      return 'Ya existe una cuenta con ese correo. Proba ingresar.';
    }
    return error.message;
  }

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (_register) {
        final response = await widget.client.auth.signUp(
          email: _email.text.trim(),
          password: _password.text,
          data: {'username': _username.text.trim()},
        );
        if (response.session == null && mounted) {
          setState(() {
            _isError = false;
            _message =
                'Revisa tu correo para confirmar la cuenta. Despues, inicia sesion.';
            _register = false;
          });
        }
      } else {
        await widget.client.auth.signInWithPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
    } on AuthException catch (error) {
      if (mounted)
        setState(() {
          _isError = true;
          _message = _authMessage(error);
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _isError = true;
          _message =
              'No se pudo conectar. Comproba tu conexion e intenta de nuevo.';
        });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() {
        _isError = true;
        _message = 'Ingresa primero tu correo electronico.';
      });
      return;
    }
    try {
      await widget.client.auth.resetPasswordForEmail(email);
      if (mounted)
        setState(() {
          _isError = false;
          _message = 'Te enviamos un enlace para recuperar el acceso.';
        });
    } on AuthException catch (error) {
      if (mounted)
        setState(() {
          _isError = true;
          _message = _authMessage(error);
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _isError = true;
          _message = 'No pudimos enviar el correo. Intenta nuevamente.';
        });
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
                  const SizedBox(height: 32),
                  Text(
                    _register ? 'Crea tu cuenta' : 'Bienvenido de nuevo',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _register
                        ? 'Tu nombre de usuario aparecera en los precios que aportes.'
                        : 'Inicia sesion para buscar y comparar precios.',
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
                        : (value) => setState(() {
                            _register = value.first;
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
                          : 'Usa 3 a 30 letras, numeros o guion bajo.',
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Correo electronico',
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                    validator: (value) =>
                        RegExp(
                          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                        ).hasMatch(value?.trim() ?? '')
                        ? null
                        : 'Ingresa un correo valido.',
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
                        : 'Minimo 8 caracteres.',
                    onFieldSubmitted: (_) => _submit(),
                  ),
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
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_register ? 'Crear cuenta' : 'Ingresar'),
                    ),
                  ),
                  if (!_register)
                    TextButton(
                      onPressed: _busy ? null : _resetPassword,
                      child: const Text('Olvide mi contraseña'),
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
