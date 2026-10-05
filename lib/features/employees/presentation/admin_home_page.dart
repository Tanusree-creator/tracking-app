import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/notifications/reminder_sync.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_pill.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/employee_repository.dart';
import 'employee_providers.dart';

class AdminHomePage extends ConsumerStatefulWidget {
  const AdminHomePage({super.key});
  @override
  ConsumerState<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends ConsumerState<AdminHomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(notificationServiceProvider).requestPermission();
      await syncVisitReminders(ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    final employees = ref.watch(employeesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).signOut(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await context.push<bool>('/admin/create-employee');
          if (created == true) ref.invalidate(employeesProvider);
        },
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add employee'),
      ),
      body: AnimatedSwitcher(
        duration: Motion.normal,
        child: employees.when(
          loading: () => const Center(
              key: ValueKey('loading'), child: CircularProgressIndicator()),
          error: (e, _) => EmptyState(
            key: const ValueKey('error'),
            icon: Icons.cloud_off_outlined,
            title: 'Could not load your team',
            message: '$e',
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(employeesProvider),
          ),
          data: (list) => list.isEmpty
              ? const EmptyState(
                  key: ValueKey('empty'),
                  icon: Icons.groups_outlined,
                  title: 'No employees yet',
                  message: 'Add the first one to give them a login.',
                )
              : RefreshIndicator(
                  key: const ValueKey('list'),
                  onRefresh: () async => ref.invalidate(employeesProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                        Space.md, Space.xs, Space.md, 96),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
                    itemBuilder: (_, i) => _EmployeeTile(employee: list[i]),
                  ),
                ),
        ),
      ),
    );
  }
}

class _EmployeeTile extends StatelessWidget {
  const _EmployeeTile({required this.employee});
  final Employee employee;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final e = employee;
    final isAdmin = e.role == 'admin';
    final label = e.name.isEmpty ? e.email : e.name;
    return AppCard(
      child: Row(children: [
        CircleAvatar(
          backgroundColor: t.colorScheme.primary.withValues(alpha: 0.12),
          foregroundColor: t.colorScheme.primary,
          child: Text(label[0].toUpperCase()),
        ),
        const SizedBox(width: Space.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: t.textTheme.labelLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: Space.xxs),
            Text(e.email,
                style: t.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ]),
        ),
        const SizedBox(width: Space.sm),
        StatusPill(
          label: isAdmin ? 'Admin' : 'Technician',
          color: isAdmin ? t.colorScheme.tertiary : t.colorScheme.primary,
        ),
      ]),
    );
  }
}
