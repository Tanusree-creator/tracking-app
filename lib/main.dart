import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/splash_screen.dart';
import 'services/access_provider.dart';
import 'services/app_notifications_provider.dart';
import 'services/notification_service.dart';
import 'services/tracking_provider.dart';
import 'theme/app_theme.dart';

// Run with: flutter run --dart-define-from-file=env.json
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseAnonKey);
  await NotificationService.instance.init();
  runApp(const FieldFlowApp());
}

class FieldFlowApp extends StatelessWidget {
  const FieldFlowApp({super.key});

  @override
  Widget build(BuildContext context) => MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AccessProvider()),
          ChangeNotifierProvider(create: (_) => AppNotificationsProvider()),
          ChangeNotifierProvider(create: (c) => TrackingProvider(c.read<AppNotificationsProvider>())),
        ],
        child: MaterialApp(
          title: 'FieldFlow',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          home: const SplashScreen(),
        ),
      );
}
