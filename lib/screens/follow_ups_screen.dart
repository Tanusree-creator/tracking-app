import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../l10n/l10n.dart';
import '../models/office_models.dart';
import '../services/staff_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';
import '../widgets/pickers.dart';

/// Office staff: schools and people to call (or visit later) with a date and time. The admin is told when one
/// is added and sees it on the admin calendar.
class FollowUpsScreen extends StatelessWidget {
  const FollowUpsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<StaffProvider>();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    bool onDay(FollowUp f, int plus) {
      final d = DateTime(f.remindAt.year, f.remindAt.month, f.remindAt.day);
      return d == today.add(Duration(days: plus));
    }

    final open = sp.followUps.where((f) => !f.done).toList();
    final overdue = open.where((f) => f.remindAt.isBefore(now) && !onDay(f, 0)).toList();
    final todays = open.where((f) => onDay(f, 0)).toList();
    final later = open.where((f) => f.remindAt.isAfter(now) && !onDay(f, 0)).toList();
    final done = sp.followUps.where((f) => f.done).toList().reversed.take(20).toList();

    Widget group(String title, List<FollowUp> list, {Color? color}) => list.isEmpty
        ? const SizedBox.shrink()
        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionTitle(title.tr),
            for (final (i, f) in list.indexed) Padding(padding: const EdgeInsets.only(bottom: Sp.s), child: FollowUpCard(f).enter(i)),
          ]);

    return Scaffold(
      appBar: AppBar(title: Text('Calls & Follow-ups'.tr, style: const TextStyle(fontWeight: FontWeight.w700))),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 84),
        child: FloatingActionButton.extended(
          onPressed: () => showFollowUpSheet(context),
          icon: const Icon(Icons.add_call),
          label: Text('Add'.tr),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: sp.refresh,
        child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(Sp.l, 0, Sp.l, 130), children: [
          if (sp.error != null) ErrorState(sp.error!.tr, sp.refresh),
          if (sp.followUps.isEmpty && sp.error == null)
            EmptyState(Icons.phone_in_talk_outlined, 'No calls planned. Add the schools and people you need to follow up with.'),
          group('Overdue', overdue),
          group('Today', todays),
          group('Upcoming', later),
          group('Done', done),
        ]),
      ),
    );
  }
}

class FollowUpCard extends StatelessWidget {
  final FollowUp f;
  const FollowUpCard(this.f, {super.key});

  @override
  Widget build(BuildContext context) {
    final sp = context.read<StaffProvider>();
    final color = f.isCall ? const Color(0xFF7C4DFF) : AppColors.green;
    final lang = L10n.current.name;
    return InfoCard(
      borderColor: f.overdue ? AppColors.red.withValues(alpha: .6) : null,
      leading: IconBadge(f.isCall ? Icons.phone_in_talk : Icons.storefront, f.done ? AppColors.muted : color),
      title: f.org.isEmpty ? f.name : '${f.name} · ${f.org}',
      subtitle: f.done && f.result.isNotEmpty ? f.result : f.purpose,
      chips: [
        StatusChip(DateFormat('EEE d MMM · h:mm a', lang).format(f.remindAt), f.overdue ? AppColors.red : AppColors.muted, icon: Icons.schedule),
        StatusChip((f.isCall ? 'Call' : 'Visit').tr, color),
        if (f.done) StatusChip('Done'.tr, AppColors.green, icon: Icons.check),
      ],
      trailing: Column(children: [
        if (f.phone.isNotEmpty && !f.done)
          IconButton(
            tooltip: 'Call now'.tr,
            icon: const Icon(Icons.call, color: AppColors.green),
            onPressed: () => launchUrl(Uri(scheme: 'tel', path: f.phone)),
          ),
        if (!f.done)
          IconButton(
            tooltip: 'Mark done'.tr,
            icon: const Icon(Icons.check_circle_outline),
            onPressed: () => _finish(context, sp),
          ),
      ]),
      onTap: () => showFollowUpSheet(context, existing: f),
    );
  }

  Future<void> _finish(BuildContext context, StaffProvider sp) async {
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('How did it go?'.tr),
        content: GlowTextField(controller: note, maxLines: 3, textCapitalization: TextCapitalization.sentences, decoration: InputDecoration(labelText: 'Result (optional)'.tr)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel'.tr)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(minimumSize: const Size(100, 44)), child: Text('Done'.tr)),
        ],
      ),
    );
    if (ok != true) return;
    f
      ..status = 'done'
      ..result = note.text.trim();
    try {
      await sp.saveFollowUp(f);
    } catch (e) {
      if (context.mounted) toast(context, 'Could not save: ${e.toString().replaceFirst('Exception: ', '')}', type: ToastType.error);
    }
  }
}

void showFollowUpSheet(BuildContext context, {FollowUp? existing}) {
  final sp = context.read<StaffProvider>();
  final name = TextEditingController(text: existing?.name);
  final org = TextEditingController(text: existing?.org);
  final phone = TextEditingController(text: existing?.phone);
  final purpose = TextEditingController(text: existing?.purpose);
  var kind = existing?.kind ?? 'call';
  var when = existing?.remindAt ?? DateTime.now().add(const Duration(hours: 1));
  final form = GlobalKey<FormState>();
  var busy = false;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(Sp.xl, 0, Sp.xl, MediaQuery.of(ctx).viewInsets.bottom + Sp.xl),
        child: Form(
          key: form,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text((existing == null ? 'New follow-up' : 'Edit follow-up').tr, style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: Sp.l),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: 'call', icon: const Icon(Icons.phone_in_talk), label: Text('Call'.tr)),
                ButtonSegment(value: 'visit', icon: const Icon(Icons.storefront), label: Text('Visit'.tr)),
              ],
              selected: {kind},
              onSelectionChanged: (s) => setState(() => kind = s.first),
            ),
            const SizedBox(height: Sp.m),
            GlowTextField(controller: name, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: 'Person to contact'.tr, prefixIcon: const Icon(Icons.person_outline)), validator: (v) => (v ?? '').trim().isEmpty ? 'Required'.tr : null),
            const SizedBox(height: Sp.m),
            GlowTextField(controller: org, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: 'School / organisation'.tr, prefixIcon: const Icon(Icons.school_outlined))),
            const SizedBox(height: Sp.m),
            GlowTextField(controller: phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: 'Phone number'.tr, prefixIcon: const Icon(Icons.phone_outlined))),
            const SizedBox(height: Sp.m),
            GlowTextField(controller: purpose, textCapitalization: TextCapitalization.sentences, maxLines: 2, decoration: InputDecoration(labelText: 'What to discuss'.tr)),
            const SizedBox(height: Sp.m),
            DateTimeField(label: 'Date and time'.tr, value: when, onChanged: (d) => setState(() => when = d)),
            const SizedBox(height: Sp.xs),
            Text('Your admin is notified and sees this on the calendar.'.tr, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
            const SizedBox(height: Sp.l),
            Row(children: [
              if (existing != null)
                Padding(
                  padding: const EdgeInsets.only(right: Sp.m),
                  child: IconButton.outlined(
                    tooltip: 'Delete'.tr,
                    icon: const Icon(Icons.delete_outline, color: AppColors.red),
                    onPressed: () async {
                      if (!await confirm(ctx, 'Delete follow-up?', existing.name, action: 'Delete', danger: true)) return;
                      try {
                        await sp.deleteFollowUp(existing);
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        if (ctx.mounted) toast(ctx, 'Could not save: ${e.toString().replaceFirst('Exception: ', '')}', type: ToastType.error);
                      }
                    },
                  ),
                ),
              Expanded(
                child: FilledButton(
                  onPressed: busy
                      ? null
                      : () async {
                          if (!form.currentState!.validate()) return;
                          setState(() => busy = true);
                          try {
                            final f = existing ?? FollowUp(id: const Uuid().v4(), name: '', remindAt: when);
                            f
                              ..name = name.text.trim()
                              ..org = org.text.trim()
                              ..phone = phone.text.trim()
                              ..purpose = purpose.text.trim()
                              ..kind = kind
                              ..remindAt = when;
                            await sp.saveFollowUp(f, isNew: existing == null);
                            if (ctx.mounted) Navigator.pop(ctx);
                          } catch (e) {
                            setState(() => busy = false);
                            if (ctx.mounted) toast(ctx, 'Could not save: ${e.toString().replaceFirst('Exception: ', '')}', type: ToastType.error);
                          }
                        },
                  child: Text('Save'.tr),
                ),
              ),
            ]),
          ]),
        ),
      ),
    ),
  );
}
