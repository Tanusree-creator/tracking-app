import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import 'glass.dart';

/// Date picker followed by a time picker. Returns null if either is cancelled.
Future<DateTime?> pickDateTime(BuildContext context, DateTime initial, {DateTime? first, DateTime? last}) async {
  final now = DateTime.now();
  final date = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: first ?? DateTime(now.year - 1),
    lastDate: last ?? DateTime(now.year + 3),
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

/// Tappable field that shows a date and time and opens [pickDateTime].
class DateTimeField extends StatelessWidget {
  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  const DateTimeField({super.key, required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          final d = await pickDateTime(context, value);
          if (d != null) onChanged(d);
        },
        child: InputDecorator(
          decoration: InputDecoration(labelText: label.tr, prefixIcon: const Icon(Icons.event)),
          child: Text(DateFormat('EEE, d MMM y · h:mm a', L10n.current.name).format(value), style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      );
}

/// Standard modal bottom sheet for forms: scrolls above the keyboard.
Future<T?> showFormSheet<T>(BuildContext context, {required String title, required List<Widget> children}) => showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(Sp.xl, 0, Sp.xl, MediaQuery.of(ctx).viewInsets.bottom + Sp.xl),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title.tr, style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: Sp.l),
          ...children,
        ]),
      ),
    );

/// Round avatar-like icon used on list rows.
class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const IconBadge(this.icon, this.color, {super.key, this.size = 46});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color.withValues(alpha: .15), borderRadius: BorderRadius.circular(size / 3)),
        child: Icon(icon, color: color, size: size * .5),
      );
}

/// Glass card row used by lists of tasks, calls and leave.
class InfoCard extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? subtitle;
  final List<Widget> chips;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? borderColor;
  const InfoCard({super.key, required this.leading, required this.title, this.subtitle, this.chips = const [], this.trailing, this.onTap, this.borderColor});

  @override
  Widget build(BuildContext context) => GlassCard(
        onTap: onTap,
        borderColor: borderColor,
        child: Padding(
          padding: const EdgeInsets.all(Sp.m),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            leading,
            const SizedBox(width: Sp.m),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                ],
                if (chips.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 4, children: chips),
                ],
              ]),
            ),
            ?trailing,
          ]),
        ),
      );
}
