import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'firebase_config.dart';
import 'services/theme_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final themePreferences = ThemePreferences();
    final darkMode = await themePreferences.loadDarkMode();
    const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
    const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    SupabaseClient? client;
    FirebaseAuth? firebaseAuth;
    if (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
      await Firebase.initializeApp(
        options: ConvieneFirebaseOptions.currentPlatform,
      );
      firebaseAuth = FirebaseAuth.instance;
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseKey,
        accessToken: () async {
          final user = firebaseAuth?.currentUser;
          if (user == null || !user.emailVerified) return null;
          return user.getIdToken();
        },
      );
      client = Supabase.instance.client;
    }
    runApp(
      ConvieneApp(
        initialDarkMode: darkMode,
        themePreferences: themePreferences,
        supabaseClient: client,
        firebaseAuth: firebaseAuth,
      ),
    );
  } catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: error, stack: stackTrace),
    );
    runApp(const _StartupErrorApp());
  }
}

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp();

  @override
  Widget build(BuildContext context) => const MaterialApp(
    home: Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined, size: 40),
              SizedBox(height: 16),
              Text(
                'No pudimos iniciar Conviene. Revisá tu conexión y volvé a cargar la app.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
