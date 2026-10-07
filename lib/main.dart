import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/splash_screen.dart';
import 'services/access_provider.dart';
import 'services/app_notifications_provider.dart';
import 'services/notification_service.dart';
import 'services/theme_controller.dart';
import 'services/tracking_provider.dart';
import 'theme/app_theme.dart';
import 'widgets/glass.dart';

// Run with: flutter run --dart-define-from-file=env.json
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseAnonKey);
  await NotificationService.instance.init();
  final theme = ThemeController();
  await theme.load();
  runApp(FieldFlowApp(theme: theme));
}

class FieldFlowApp extends StatelessWidget {
  final ThemeController theme;
  const FieldFlowApp({super.key, required this.theme});

  @override
  Widget build(BuildContext context) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: theme),
          ChangeNotifierProvider(create: (_) => AccessProvider()),
          ChangeNotifierProvider(create: (_) => AppNotificationsProvider()),
          ChangeNotifierProvider(create: (c) => TrackingProvider(c.read<AppNotificationsProvider>())),
        ],
        child: Consumer<ThemeController>(
          builder: (_, tc, _) => MaterialApp(
            title: 'Merit Publication',
            debugShowCheckedModeBanner: false,
            themeMode: tc.mode,
            theme: buildTheme(Brightness.light),
            darkTheme: buildTheme(Brightness.dark),
            // Keep layouts intact on phones with a very large system font.
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: MediaQuery.textScalerOf(context).clamp(minScaleFactor: 1.0, maxScaleFactor: 1.15),
              ),
              child: Stack(children: [const Positioned.fill(child: GlassBackground()), child!]),
            ),
            home: const SplashScreen(),
          ),
        ),
      );
}
