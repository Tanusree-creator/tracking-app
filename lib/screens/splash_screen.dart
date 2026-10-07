import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../services/access_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/anim.dart';
import '../widgets/brand.dart';
import 'admin/admin_shell.dart';
import 'login_screen.dart';
import 'tech_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _go();
  }

  /// Already signed in? Go straight to the app. Otherwise show the sign-in page.
  Future<void> _go() async {
    final access = context.read<AccessProvider>();
    final results = await Future.wait([
      access.restore().catchError((_) => false),
      Future<void>.delayed(const Duration(milliseconds: 1500)),
    ]);
    if (!mounted) return;
    final restored = results.first as bool;
    final Widget next = !restored ? const LoginScreen() : (access.isAdmin ? const AdminShell() : const TechShell());
    Navigator.of(context).pushReplacement(slideRoute(next));
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final w = MediaQuery.sizeOf(context).width;
    return Scaffold(
      // The app-wide glass background shows through; the logo is a transparent PNG.
      backgroundColor: Colors.transparent,
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          BrandLogo(size: (w * .78).clamp(220, 380), white: dark)
              .animate()
              .scale(begin: const Offset(.8, .8), duration: 800.ms, curve: Curves.easeOutBack)
              .fadeIn(duration: 600.ms),
          const SizedBox(height: 28),
          Text('MERIT PUBLICATION',
                  style: TextStyle(
                      color: dark ? Colors.white : AppColors.blue800, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 3))
              .animate(delay: 350.ms)
              .fadeIn(duration: 500.ms)
              .slideY(begin: .3, end: 0),
          const SizedBox(height: 6),
          const Text('Every page, every reader, on time.', style: TextStyle(color: AppColors.muted, fontStyle: FontStyle.italic, letterSpacing: .3))
              .animate(delay: 550.ms)
              .fadeIn(duration: 500.ms),
        ]),
      ),
    );
  }
}
