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
  AppState? _state;
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<firebase.User?>? _firebaseSubscription;
  firebase.User? _firebaseUser;
  bool _profileBusy = false;
  String? _profileError;
  String? _userId;
  String? _username;
  bool _recoveringPassword = false;
  late bool _darkMode;
  late final ThemePreferences _themePreferences;

  @override
  void initState() {
    super.initState();
    _darkMode = widget.initialDarkMode;
    _themePreferences = widget.themePreferences ?? ThemePreferences();
    AppColors.setDarkMode(_darkMode);
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
    _profileBusy = true;
    _profileError = null;
    if (mounted) setState(() {});
    try {
      await user.getIdToken(true);
      final client = widget.supabaseClient!;
      final existing = await client
          .from('firebase_profiles')
          .select('username')
          .eq('uid', user.uid)
          .maybeSingle();
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
            .single();
        username = inserted['username'] as String;
      }
      if (mounted && widget.firebaseAuth?.currentUser?.uid == user.uid) {
        _setUser(user.uid, username: username);
      }
    } on PostgrestException catch (error) {
      _profileError = error.code == '23505'
          ? 'Ese nombre de usuario ya existe. Elegí otro.'
          : 'No pudimos completar tu perfil. Reintentá.';
    } catch (_) {
      _profileError = 'No pudimos conectar con la base. Reintentá.';
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
    final user = widget.firebaseAuth?.currentUser;
    if (user == null || !user.emailVerified) return;
    _profileBusy = true;
    _profileError = null;
    setState(() {});
    try {
      final row = await widget.supabaseClient!
          .from('firebase_profiles')
          .insert({'uid': user.uid, 'username': username.trim()})
          .select('username')
          .single();
      final savedUsername = row['username'] as String;
      try {
        await user.updateDisplayName(savedUsername);
      } catch (_) {
        // The database profile is authoritative; this Firebase label is optional.
      }
      if (mounted) _setUser(user.uid, username: savedUsername);
    } on PostgrestException catch (error) {
      _profileError = error.code == '23505'
          ? 'Ese nombre de usuario ya existe. Elegí otro.'
          : 'No pudimos guardar tu perfil. Reintentá.';
    } catch (_) {
      _profileError = 'No pudimos conectar con la base. Reintentá.';
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
    _state?.dispose();
    _userId = id;
    _username = username;
    if (id == null) {
      _state = null;
    } else {
      _state = AppState(
        repository: CommunityPriceRepository(
          createRepository(),
          widget.supabaseClient!,
          userId: widget.firebaseAuth == null ? null : id,
        ),
        userDataStore: LocalUserDataStore(userId: id),
      )..initialize();
      if (widget.firebaseAuth == null) unawaited(_loadUsername(id));
    }
    if (mounted) setState(() {});
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
      title: 'Conviene',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(dark: _darkMode),
      themeAnimationDuration: const Duration(milliseconds: 180),
      home: widget.supabaseClient == null
          ? const SupabaseSetupScreen()
          : widget.firebaseAuth != null
          ? _firebaseHome(state)
          : _recoveringPassword
          ? PasswordRecoveryScreen(
              client: widget.supabaseClient!,
              onCompleted: () => setState(() => _recoveringPassword = false),
              onCancel: () => widget.supabaseClient!.auth.signOut(),
            )
          : state == null
          ? AuthScreen(client: widget.supabaseClient!)
          : AppScope(
              notifier: state,
              child: AppShell(
                key: ValueKey('${_userId}_$_darkMode'),
                darkMode: _darkMode,
                onToggleDarkMode: _toggleDarkMode,
                username:
                    _username ??
                    widget
                            .supabaseClient!
                            .auth
                            .currentUser
                            ?.userMetadata?['username']
                        as String? ??
                    'usuario',
                onSignOut: () => widget.supabaseClient!.auth.signOut(),
              ),
            ),
    );
  }

  Widget _firebaseHome(AppState? state) {
    final user = _firebaseUser;
    if (user == null) return FirebaseAuthScreen(auth: widget.firebaseAuth!);
    if (!user.emailVerified) {
      return FirebaseVerificationScreen(
        user: user,
        onRefresh: _refreshFirebaseVerification,
        onSignOut: widget.firebaseAuth!.signOut,
      );
    }
    if (state == null) {
      if (_profileError == null) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return FirebaseProfileScreen(
        initialUsername: user.displayName ?? '',
        error: _profileError!,
        busy: _profileBusy,
        onSave: _saveFirebaseUsername,
        onRetry: () => _ensureFirebaseProfile(user),
        onSignOut: widget.firebaseAuth!.signOut,
      );
    }
    return AppScope(
      notifier: state,
      child: AppShell(
        key: ValueKey('${user.uid}_$_darkMode'),
        darkMode: _darkMode,
        onToggleDarkMode: _toggleDarkMode,
        username: _username ?? user.displayName ?? 'usuario',
        onSignOut: widget.firebaseAuth!.signOut,
      ),
    );
  }
}
