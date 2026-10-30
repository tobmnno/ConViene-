import 'package:conviene/screens/auth_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('requires username, email, and password for registration', (
    tester,
  ) async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'sb_publishable_test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MaterialApp(home: AuthScreen(client: client)));
    await tester.tap(find.text('Crear cuenta'));
    await tester.pump();

    expect(
      find.text('Usa 3 a 30 letras, numeros o guion bajo.'),
      findsOneWidget,
    );
    expect(find.text('Ingresa un correo valido.'), findsOneWidget);
    expect(find.text('Minimo 8 caracteres.'), findsOneWidget);
  });

  testWidgets('keeps auth mode labels on one line on narrow screens', (
    tester,
  ) async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'sb_publishable_test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    await tester.binding.setSurfaceSize(const Size(220, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MaterialApp(home: AuthScreen(client: client)));

    expect(tester.getSize(find.text('Registrarme')).height, lessThan(30));
  });

  testWidgets('requires a new password and confirmation on recovery', (
    tester,
  ) async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'sb_publishable_test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PasswordRecoveryScreen(
          client: client,
          onCompleted: () {},
          onCancel: () {},
        ),
      ),
    );

    await tester.tap(find.text('Guardar contraseña'));
    await tester.pump();

    expect(find.text('Minimo 8 caracteres.'), findsOneWidget);
    expect(find.text('Repetí la contraseña.'), findsOneWidget);
  });
}
