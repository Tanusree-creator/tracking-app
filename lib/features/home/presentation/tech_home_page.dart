import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/reminder_sync.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/route_map.dart';
import '../../../core/widgets/status_pill.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../tracking/presentation/tracking_controller.dart';

class TechHomePage extends ConsumerStatefulWidget {
  const TechHomePage({super.key});
  @override
  ConsumerState<TechHomePage> createState() => _TechHomePageState();
}

class _TechHomePageState extends ConsumerState<TechHomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(notificationServiceProvider).requestPermission();
      await syncVisitReminders(ref);
      await ref.read(trackingProvider.notifier).restore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider)!;
    final onShift = ref.watch(trackingProvider.select((s) => s.onShift));
    final name = user.name ?? user.email.split('@').first;

    return Scaffold(
      appBar: AppBar(
        title: Text('Hi, $name'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: onShift
                ? null
                : () => ref.read(authProvider.notifier).signOut(),
          ),
        ],
      ),
      body: Padding(
        padding: Space.screen,
        child: Column(children: [
          const _ShiftCard(),
          const SizedBox(height: Space.md),
          const Expanded(child: _TrailMap()),
        ]),
      ),
    );
  }
}

class _ShiftCard extends ConsumerWidget {
  const _ShiftCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(trackingProvider);
    final ctrl = ref.read(trackingProvider.notifier);
    final t = Theme.of(context);
    final accent = t.colorScheme.tertiary;

    return AppCard(
      padding: const EdgeInsets.all(Space.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          AnimatedContainer(
            duration: Motion.normal,
            curve: Motion.curve,
            padding: const EdgeInsets.all(Space.sm),
            decoration: BoxDecoration(
              color: (s.onShift ? accent : t.colorScheme.outline)
                  .withValues(alpha: 0.12),
              borderRadius: Radii.medium,
            ),
            child: Icon(
              s.onShift ? Icons.timer_outlined : Icons.bedtime_outlined,
              color: s.onShift ? accent : t.colorScheme.outline,
            ),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.onShift ? 'Shift in progress' : 'Off shift',
                  style: t.textTheme.titleMedium),
              const SizedBox(height: Space.xxs),
              Text('${(s.distanceM / 1000).toStringAsFixed(2)} km travelled',
                  style: t.textTheme.bodySmall),
            ]),
          ),
          if (s.onShift) StatusPill(label: 'LIVE', color: accent),
        ]),
        const SizedBox(height: Space.lg),
        AppButton(
          label: s.onShift ? 'Clock out' : 'Clock in',
          icon: s.onShift
              ? Icons.stop_circle_outlined
              : Icons.play_circle_outline,
          loading: s.busy,
          destructive: s.onShift,
          onPressed: s.onShift ? ctrl.clockOut : ctrl.clockIn,
        ),
        AnimatedSize(
          duration: Motion.fast,
          curve: Motion.curve,
          alignment: Alignment.topCenter,
          child: s.error == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: Space.sm),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.error!,
                            style: t.textTheme.bodySmall
                                ?.copyWith(color: t.colorScheme.error)),
                        if (s.error!.contains('Settings'))
                          TextButton(
                            onPressed:
                                ref.read(locationServiceProvider).openSettings,
                            child: const Text('Open settings'),
                          ),
                      ]),
                ),
        ),
      ]),
    );
  }
}

/// Isolated so GPS updates repaint only the map, not the whole screen.
class _TrailMap extends ConsumerWidget {
  const _TrailMap();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trail = ref.watch(trackingProvider.select((s) => s.trail));
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: Radii.medium,
          boxShadow: AppShadows.soft(context),
        ),
        child: RouteMap(trail: trail),
      ),
    );
  }
}
