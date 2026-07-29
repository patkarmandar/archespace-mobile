import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:archespace_mobile/src/app.dart';
import 'package:archespace_mobile/src/features/settings/application/appearance_controller.dart';
import 'package:archespace_mobile/src/shared/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!AppConfig.isConfigured) {
    runApp(const _ConfigErrorApp());
    return;
  }

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    // Supabase renamed the anon key to "publishable key"; the value is the same
    // one the web app uses (SUPABASE_ANON_KEY).
    publishableKey: AppConfig.supabaseAnonKey,
  );
  await AppearanceController.instance.load();

  runApp(const ArcheApp());
}

/// Shown when SUPABASE_URL / SUPABASE_ANON_KEY were not provided at build time.
class _ConfigErrorApp extends StatelessWidget {
  const _ConfigErrorApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text(
              'Missing Supabase configuration.\n\n'
              'Run with:\n'
              'flutter run --dart-define-from-file=env.json\n\n'
              '(see env.example.json)',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
