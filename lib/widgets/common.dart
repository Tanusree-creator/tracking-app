import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import 'glass.dart';

class StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color? color;
  final VoidCallback? onTap;
  const StatTile({super.key, required this.icon, required this.value, required this.label, this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.accent;
    final t = Theme.of(context).textTheme;
    return GlassCard(
      blur: 14,
      onTap: onTap,
      child: Padding(
          padding: const EdgeInsets.all(Sp.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Container(
                  padding: const EdgeInsets.all(Sp.s),
                  decoration: BoxDecoration(color: c.withValues(alpha: .15), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, size: 22, color: c),
                ),
                if (onTap != null) const Icon(Icons.chevron_right, color: AppColors.muted),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(value,
                      style: t.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()])),
                ),
                const SizedBox(height: 2),
                Text(label.tr, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall?.copyWith(color: AppColors.muted)),
              ]),
            ],
          ),
        ),
    );
  }
}

class StatGrid extends StatelessWidget {
  final List<StatTile> tiles;
  const StatGrid(this.tiles, {super.key});

  @override
  Widget build(BuildContext context) => GridView(
        shrinkWrap: true,
        padding: EdgeInsets.zero, // otherwise it inherits the floating nav bar's inset as a big gap
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: Sp.m,
          crossAxisSpacing: Sp.m,
          mainAxisExtent: 136,
        ),
        children: [for (var i = 0; i < tiles.length; i++) tiles[i].enter(i)],
      );
}

class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const StatusChip(this.label, this.color, {super.key, this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: .15), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null)
            Icon(icon, size: 13, color: color)
          else
            Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label.tr, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const EmptyState(this.icon, this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 44, color: AppColors.muted),
            const SizedBox(height: 10),
            Text(text.tr, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
          ]),
        ),
      );
}

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorState(this.message, this.onRetry, {super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off, size: 44, color: AppColors.red),
            const SizedBox(height: 10),
            Text(message.tr, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: Text('Retry'.tr)),
          ]),
        ),
      );
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: Sp.xl, bottom: Sp.m),
        child: Row(children: [
          Expanded(child: Text(text.tr, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600))),
          if (trailing != null) trailing!,
        ]),
      );
}

enum ToastType { success, error, info }

OverlayEntry? _toastEntry;

/// Glass notification bar that slides in from the top. Replaces SnackBars.
void toast(BuildContext context, String message, {ToastType? type}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  _toastEntry?.remove();
  message = message.tr;
  final kind = type ?? _inferToastType(message);
  late OverlayEntry entry;
  entry = OverlayEntry(builder: (_) => _Toast(message, kind, onDone: () {
        if (_toastEntry == entry) _toastEntry = null;
        entry.remove();
      }));
  _toastEntry = entry;
  overlay.insert(entry);
}

/// Backwards-compatible alias used across the app.
void snack(BuildContext context, String msg) => toast(context, msg);

ToastType _inferToastType(String m) {
  final s = m.toLowerCase();
  if (RegExp(r'could not|incorrect|cannot|failed|error|denied|not authorised|clock in').hasMatch(s)) return ToastType.error;
  if (RegExp(r'created|updated|started|ended|completed|approved|rejected|copied|sent').hasMatch(s)) return ToastType.success;
  return ToastType.info;
}

class _Toast extends StatefulWidget {
  final String message;
  final ToastType type;
  final VoidCallback onDone;
  const _Toast(this.message, this.type, {required this.onDone});

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _c.forward();
    _timer = Timer(const Duration(milliseconds: 3200), _dismiss);
  }

  Future<void> _dismiss() async {
    _timer?.cancel();
    if (!mounted) return;
    await _c.reverse();
    widget.onDone();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (widget.type) {
      ToastType.success => (Icons.check_circle_rounded, AppColors.green),
      ToastType.error => (Icons.error_rounded, AppColors.red),
      ToastType.info => (Icons.info_rounded, AppColors.accent),
    };
    final curved = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic, reverseCurve: Curves.easeIn);
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, -1.4), end: Offset.zero).animate(curved),
        child: FadeTransition(
          opacity: curved,
          child: GestureDetector(
            onTap: _dismiss,
            onVerticalDragEnd: (d) {
              if ((d.primaryVelocity ?? 0) < 0) _dismiss();
            },
            child: GlassCard(
              blur: 20,
              radius: 18,
              borderColor: color.withValues(alpha: .55),
              tint: Theme.of(context).brightness == Brightness.dark
                  ? Color.alphaBlend(color.withValues(alpha: .14), const Color(0xCC161B26))
                  : Color.alphaBlend(color.withValues(alpha: .10), Colors.white.withValues(alpha: .82)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: color.withValues(alpha: .18), shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(widget.message, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

Future<bool> confirm(BuildContext context, String title, String message, {String action = 'Confirm', bool danger = false}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title.tr),
      content: Text(message.tr),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel'.tr)),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(
              minimumSize: const Size(100, 44), backgroundColor: danger ? AppColors.red : AppColors.accent),
          child: Text(action.tr),
        ),
      ],
    ),
  );
  return ok == true;
}
