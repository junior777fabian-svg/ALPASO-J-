import 'package:flutter/semantics.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_app.dart';
import 'admin_repository.dart';

/// Panel de administración. Se compila con:
///   flutter build web --dart-define=SUPABASE_URL=… --dart-define=SUPABASE_PUBLISHABLE_KEY=… [--dart-define=APP_ENV=prod]
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  const env = String.fromEnvironment('APP_ENV', defaultValue: 'demo');
  if (url.isEmpty || key.isEmpty) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Falta SUPABASE_URL o SUPABASE_PUBLISHABLE_KEY al compilar.',
            ),
          ),
        ),
      ),
    );
    return;
  }
  await Supabase.initialize(url: url, publishableKey: key);
  if (const bool.fromEnvironment('FORCE_SEMANTICS')) {
    SemanticsBinding.instance.ensureSemantics();
  }
  runApp(
    AdminApp(
      repository: SupabaseAdminRepository(Supabase.instance.client),
      demo: env != 'prod',
    ),
  );
}
