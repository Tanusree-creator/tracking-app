import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'l10n/l10n.dart';
import 'screens/splash_screen.dart';
import 'services/access_provider.dart';
import 'services/app_notifications_provider.dart';
import 'services/notification_service.dart';
import 'services/staff_provider.dart';
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
  final l10n = L10n();
  await l10n.load();
  runApp(FieldFlowApp(theme: theme, l10n: l10n));
}

class FieldFlowApp extends StatelessWidget {
  final ThemeController theme;
  final L10n l10n;
  const FieldFlowApp({super.key, required this.theme, required this.l10n});

  @override
  Widget build(BuildContext context) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: theme),
          ChangeNotifierProvider.value(value: l10n),
          ChangeNotifierProvider(create: (_) => AccessProvider()),
          ChangeNotifierProvider(create: (_) => AppNotificationsProvider()),
          ChangeNotifierProvider(create: (c) => TrackingProvider(c.read<AppNotificationsProvider>())),
          ChangeNotifierProvider(create: (c) => StaffProvider(c.read<AppNotificationsProvider>())),
        ],
        child: Consumer2<ThemeController, L10n>(
          builder: (_, tc, l, _) => MaterialApp(
            title: 'Merit Publication'.tr,
            debugShowCheckedModeBanner: false,
            locale: l.lang.locale,
            supportedLocales: [for (final x in AppLang.values) x.locale],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
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
