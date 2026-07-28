import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:archespace_mobile/features/auth/login_screen.dart';

void main() {
  testWidgets('login screen renders', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
  });
}
