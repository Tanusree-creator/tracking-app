import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/employees/presentation/admin_home_page.dart';
import '../../features/employees/presentation/create_employee_page.dart';
import '../../features/home/presentation/tech_home_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: refresh,
    redirect: (context, state) {
      final user = ref.read(authProvider);
      final loc = state.matchedLocation;
      if (user == null) return loc == '/login' ? null : '/login';
      final home = user.isAdmin ? '/admin' : '/home';
      if (loc == '/login') return home;
      if (loc.startsWith('/admin') && !user.isAdmin) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/home', builder: (_, _) => const TechHomePage()),
      GoRoute(
        path: '/admin',
        builder: (_, _) => const AdminHomePage(),
        routes: [
          GoRoute(
            path: 'create-employee',
            builder: (_, _) => const CreateEmployeePage(),
          ),
        ],
      ),
    ],
  );
});
