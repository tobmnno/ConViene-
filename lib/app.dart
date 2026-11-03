import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'repositories/community_price_repository.dart';
import 'repositories/repository_factory.dart';
import 'screens/app_shell.dart';
import 'screens/auth_screen.dart';
import 'screens/firebase_auth_screen.dart';
import 'services/theme_preferences.dart';
import 'services/user_data_store.dart';
import 'state/app_scope.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

class ConvieneApp extends StatefulWidget {
  const ConvieneApp({
    super.key,
    this.initialDarkMode = false,
    this.themePreferences,
    this.supabaseClient,
    this.firebaseAuth,
  });

  final bool initialDarkMode;
  final ThemePreferences? themePreferences;
  final SupabaseClient? supabaseClient;
  final firebase.FirebaseAuth? firebaseAuth;

  @override
  State<ConvieneApp> createState() => _ConvieneAppState();
}

class _ConvieneAppState extends State<ConvieneApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  AppState? _state;
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<firebase.User?>? _firebaseSubscription;
  firebase.User? _firebaseUser;
  bool _profileBusy = false;
  String? _profileError;
  String? _userId;
  String? _username;
  bool _recoveringPassword = false;
  bool _showAuth = false;
  late bool _darkMode;
  late final ThemePreferences _themePreferences;

  @override
  void initState() {
    super.initState();
    _darkMode = widget.initialDarkMode;
    _themePreferences = widget.themePreferences ?? ThemePreferences();
    AppColors.setDarkMode(_darkMode);
    _state = _createState(null)..initialize();
    final client = widget.supabaseClient;
    if (client != null && widget.firebaseAuth != null) {
      _firebaseUser = widget.firebaseAuth!.currentUser;
      _firebaseSubscription = widget.firebaseAuth!.userChanges().listen(
        _onFirebaseUser,
      );
      _onFirebaseUser(_firebaseUser);
    } else if (client != null) {
      _setUser(client.auth.currentUser?.id);
      _authSubscription = client.auth.onAuthStateChange.listen((event) {
        if (!mounted) return;
        _setUser(event.session?.user.id);
        if (event.session?.user.id != null) setState(() => _showAuth = false);
        if (event.event == AuthChangeEvent.passwordRecovery ||
            event.event == AuthChangeEvent.signedOut) {
          setState(() {
            _recoveringPassword =
                event.event == AuthChangeEvent.passwordRecovery;
          });
        }
      });
    }
  }

  void _onFirebaseUser(firebase.User? user) {
    if (!mounted) return;
    _firebaseUser = user;
    if (user == null || !user.emailVerified) {
      _profileError = null;
      _setUser(null);
      setState(() {});
      return;
    }
    if (_userId != user.uid && !_profileBusy) {
      _setUser(null);
      unawaited(_ensureFirebaseProfile(user));
    }
    setState(() {});
  }

  Future<void> _ensureFirebaseProfile(firebase.User user) async {
    if (_profileBusy) return;
    _profileBusy = true;
    if (mounted) setState(() {});
    try {
      await user.getIdToken(true).timeout(const Duration(seconds: 20));
      final client = widget.supabaseClient!;
      final existing = await client
          .from('firebase_profiles')
          .select('username')
          .eq('uid', user.uid)
          .maybeSingle()
          .timeout(const Duration(seconds: 20));
      String? username = existing?['username'] as String?;
      if (username == null) {
        final proposed = user.displayName?.trim() ?? '';
        if (!RegExp(r'^[A-Za-z0-9_]{3,30}$').hasMatch(proposed)) {
          _profileError = 'Elegí un nombre de usuario para terminar tu cuenta.';
          return;
        }
        final inserted = await client
            .from('firebase_profiles')
            .insert({'uid': user.uid, 'username': proposed})
            .select('username')
            .single()
            .timeout(const Duration(seconds: 20));
        username = inserted['username'] as String;
      }
      if (mounted && widget.firebaseAuth?.currentUser?.uid == user.uid) {
        _setUser(user.uid, username: username);
        setState(() => _showAuth = false);
      }
    } on PostgrestException catch (error) {
      _profileError = error.code == '23505'
          ? 'Ese nombre de usuario ya existe. Elegí otro.'
          : 'No pudimos completar tu perfil. Reintentá.';
    } catch (_) {
      _profileError =
          'Tu sesión está iniciada, pero la base de datos no responde. Probá Reintentar conexión en unos momentos.';
    } finally {
      _profileBusy = false;
      if (mounted) {
        setState(() {});
        final current = widget.firebaseAuth?.currentUser;
        if (current != null &&
            current.emailVerified &&
            current.uid != user.uid &&
            _userId != current.uid) {
          unawaited(_ensureFirebaseProfile(current));
        }
      }
    }
  }

  Future<void> _saveFirebaseUsername(String username) async {
    if (_profileBusy) return;
    final user = widget.firebaseAuth?.currentUser;
    if (user == null || !user.emailVerified) return;
    _profileBusy = true;
    setState(() {});
    try {
      final row = await widget.supabaseClient!
          .from('firebase_profiles')
          .insert({'uid': user.uid, 'username': username.trim()})
          .select('username')
          .single()
          .timeout(const Duration(seconds: 20));
      final savedUsername = row['username'] as String;
      try {
        await user.updateDisplayName(savedUsername);
      } catch (_) {
        // The database profile is authoritative; this Firebase label is optional.
      }
      if (mounted) {
        _setUser(user.uid, username: savedUsername);
        setState(() => _showAuth = false);
      }
    } on PostgrestException catch (error) {
      _profileError = error.code == '23505'
          ? 'Ese nombre de usuario ya existe. Elegí otro.'
          : 'No pudimos guardar tu perfil. Reintentá.';
    } catch (_) {
      _profileError =
          'Tu sesión está iniciada, pero no pudimos guardar el perfil. Reintentá cuando vuelva la conexión.';
    } finally {
      _profileBusy = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _refreshFirebaseVerification() async {
    final user = widget.firebaseAuth?.currentUser;
    if (user == null) return;
    await user.reload();
    final refreshed = widget.firebaseAuth?.currentUser;
    if (refreshed?.emailVerified == true) {
      await refreshed!.getIdToken(true);
    }
    _onFirebaseUser(refreshed);
  }

  void _setUser(String? id, {String? username}) {
    if (_userId == id) {
      if (username != null && username != _username) {
        setState(() => _username = username);
      }
      return;
    }
    final guest = id == null || _userId != null
        ? null
        : _state?.guestImportSnapshot();
    _state?.dispose();
    _userId = id;
    _username = username;
    final next = _createState(id);
    _state = next;
    final initialization = next.initialize();
    if (id != null) {
      if (widget.firebaseAuth == null) unawaited(_loadUsername(id));
      if (guest != null &&
          (guest.cartItems.isNotEmpty || guest.favoriteProductIds.isNotEmpty)) {
        unawaited(_offerGuestImport(id, guest, next, initialization));
      }
    }
    if (mounted) setState(() {});
  }

  AppState _createState(String? id) => AppState(
    repository: widget.supabaseClient == null
        ? createRepository()
        : CommunityPriceRepository(
            createRepository(),
            widget.supabaseClient!,
            userId: widget.firebaseAuth == null ? null : id,
            allowContributions: id != null,
          ),
    userDataStore: LocalUserDataStore(userId: id),
  );

  Future<void> _offerGuestImport(
    String id,
    SavedUserData guest,
    AppState state,
    Future<void> initialization,
  ) async {
    await initialization;
    final preferences = SharedPreferencesStringStore();
    final key = 'conviene.guest_import_decision.$id';
    if (await preferences.getString(key) != null || !mounted || _userId != id)
      return;
    await WidgetsBinding.instance.endOfFrame;
    final navigatorContext = _navigatorKey.currentContext;
    if (!mounted || _userId != id || navigatorContext == null) return;
    final shouldImport = await showDialog<bool>(
      context: navigatorContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Importar tus datos de invitado?'),
        content: const Text(
          'Podés sumar tu changuito y favoritos a esta cuenta. Los medios de pago quedarán separados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('No importar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Importar'),
          ),
        ],
      ),
    );
    if (shouldImport == null || !mounted || _userId != id) return;
    if (shouldImport) await state.importGuestCartAndFavorites(guest);
    await preferences.setString(key, shouldImport ? 'imported' : 'declined');
  }

  Future<void> _loadUsername(String id) async {
    try {
      final profile = await widget.supabaseClient!
          .from('profiles')
          .select('username')
          .eq('id', id)
          .single();
      if (mounted && _userId == id) {
        setState(() => _username = profile['username'] as String?);
      }
    } catch (_) {
      // The auth session still works when a profile request is interrupted.
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _firebaseSubscription?.cancel();
    _state?.dispose();
    super.dispose();
  }

  void _toggleDarkMode() {
    setState(() {
      _darkMode = !_darkMode;
      AppColors.setDarkMode(_darkMode);
    });
    unawaited(_themePreferences.saveDarkMode(_darkMode));
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Conviene',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(dark: _darkMode),
      themeAnimationDuration: const Duration(milliseconds: 180),
      builder: (context, child) => state == null
          ? child ?? const SizedBox.shrink()
          : AppScope(notifier: state, child: child ?? const SizedBox.shrink()),
      home: widget.firebaseAuth != null
          ? _firebaseHome(state)
          : widget.supabaseClient != null && _recoveringPassword
          ? PasswordRecoveryScreen(
              client: widget.supabaseClient!,
              onCompleted: () => setState(() => _recoveringPassword = false),
              onCancel: () => widget.supabaseClient!.auth.signOut(),
            )
          : widget.supabaseClient != null && _showAuth
          ? AuthScreen(
              client: widget.supabaseClient!,
              onContinueAsGuest: () => setState(() => _showAuth = false),
            )
          : _shell(state!),
    );
  }

  Widget _firebaseHome(AppState? state) {
    final user = _firebaseUser;
    if (user == null) {
      return _showAuth
          ? FirebaseAuthScreen(
              auth: widget.firebaseAuth!,
              onContinueAsGuest: () => setState(() => _showAuth = false),
            )
          : _shell(state!);
    }
    if (!user.emailVerified && _showAuth) {
      return FirebaseVerificationScreen(
        user: user,
        onRefresh: _refreshFirebaseVerification,
        onSignOut: widget.firebaseAuth!.signOut,
      );
    }
    if (!user.emailVerified) return _shell(state!);
    if (_userId != user.uid) {
      if (_profileError == null) return _shell(state!);
      return FirebaseProfileScreen(
        initialUsername: user.displayName ?? '',
        error: _profileError!,
        busy: _profileBusy,
        onSave: _saveFirebaseUsername,
        onRetry: () => _ensureFirebaseProfile(user),
        onSignOut: widget.firebaseAuth!.signOut,
      );
    }
    return _shell(state!);
  }

  Widget _shell(AppState state) => AppScope(
    notifier: state,
    child: AppShell(
      key: ValueKey('${_userId ?? 'guest'}_$_darkMode'),
      darkMode: _darkMode,
      onToggleDarkMode: _toggleDarkMode,
      username: _userId == null
          ? 'invitado'
          : (_username ?? _firebaseUser?.displayName ?? 'usuario'),
      onSignIn: _userId == null && widget.supabaseClient != null
          ? () => setState(() => _showAuth = true)
          : null,
      onSignOut: _userId == null
          ? null
          : widget.firebaseAuth != null
          ? widget.firebaseAuth!.signOut
          : () => widget.supabaseClient!.auth.signOut(),
    ),
  );
}
