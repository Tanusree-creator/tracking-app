import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/env.dart';
import 'core/notifications/notification_service.dart';
import 'core/providers.dart';
import 'core/router/app_router.dart';
import 'core/storage/session_storage.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!Env.isConfigured) {
    runApp(const _MissingConfigApp());
    return;
  }

  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabaseAnonKey,
    authOptions: FlutterAuthClientOptions(localStorage: const SecureSessionStorage()),
  );

  final notifications = NotificationService();
  await notifications.init();
  final prefs = await SharedPreferences.getInstance();

  runApp(ProviderScope(
    overrides: [
      appPrefsProvider.overrideWithValue(AppPrefs(prefs)),
      notificationServiceProvider.overrideWithValue(notifications),
    ],
    child: const FieldFlowApp(),
  ));
}

class FieldFlowApp extends ConsumerWidget {
  const FieldFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
        title: 'FieldFlow',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        routerConfig: ref.watch(routerProvider),
      );
}

class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();
  @override
  Widget build(BuildContext context) => const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Missing Supabase config.\nRun with:\nflutter run --dart-define-from-file=env.json',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
}
