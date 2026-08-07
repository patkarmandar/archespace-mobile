import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:archespace_mobile/src/features/auth/presentation/login_screen.dart';

void main() {
  testWidgets('login screen renders', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    // "Sign in" appears twice in sign-in mode: the mode selector and the
    // submit button.
    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Email'), findsOneWidget);
  });
}
