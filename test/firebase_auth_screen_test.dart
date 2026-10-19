import 'package:conviene/screens/firebase_auth_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _UnusedFirebaseAuth extends Fake implements FirebaseAuth {}

void main() {
  test('maps Firebase errors without exposing backend details', () {
    expect(
      firebaseAuthError(FirebaseAuthException(code: 'email-already-in-use')),
      contains('Ya existe una cuenta'),
    );
    expect(
      firebaseAuthError(FirebaseAuthException(code: 'invalid-credential')),
      'Correo o contraseña incorrectos.',
    );
    expect(
      firebaseAuthError(FirebaseAuthException(code: 'unexpected-internal')),
      'No pudimos completar la operación. Reintentá.',
    );
  });

  testWidgets('registration validates all required fields locally', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: FirebaseAuthScreen(auth: _UnusedFirebaseAuth())),
    );

    await tester.tap(find.text('Crear cuenta'));
    await tester.pump();

    expect(
      find.text('Usá 3 a 30 letras, números o guion bajo.'),
      findsOneWidget,
    );
    expect(find.text('Ingresá un correo válido.'), findsOneWidget);
    expect(find.text('Mínimo 8 caracteres.'), findsOneWidget);
  });

  testWidgets('password recovery requires a valid email', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: FirebaseAuthScreen(auth: _UnusedFirebaseAuth())),
    );

    await tester.tap(find.text('Ingresar').first);
    await tester.pump();
    await tester.tap(find.text('Olvidé mi contraseña'));
    await tester.pump();

    expect(
      find.text('Ingresá primero tu correo electrónico.'),
      findsOneWidget,
    );
  });
}
