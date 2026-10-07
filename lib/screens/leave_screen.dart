import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/office_models.dart';
import '../services/staff_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';
import '../widgets/pickers.dart';

(String, Color, IconData) leaveStyle(String status) => switch (status) {
      'approved' => ('Approved', AppColors.green, Icons.check_circle),
      'rejected' => ('Rejected', AppColors.red, Icons.cancel),
      _ => ('Waiting for approval', AppColors.amber, Icons.hourglass_top),
    };

String leaveRange(LeaveRequest l) {
  final lang = L10n.current.name;
  final a = DateFormat('d MMM', lang);
  final range = l.from == l.to ? DateFormat('EEE, d MMM y', lang).format(l.from) : '${a.format(l.from)} – ${DateFormat('d MMM y', lang).format(l.to)}';
  return '$range · ${l.days} ${(l.days == 1 ? 'day' : 'days').tr}';
}

/// Leave requests for any employee (marketing or office). Approved leave is marked absent on the calendar.
class LeaveScreen extends StatelessWidget {
  const LeaveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<StaffProvider>();
    return Scaffold(
      appBar: AppBar(title: Text('Leave'.tr, style: const TextStyle(fontWeight: FontWeight.w700))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _request(context),
        icon: const Icon(Icons.add),
        label: Text('Request leave'.tr),
      ),
      body: RefreshIndicator(
        onRefresh: sp.refresh,
        child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(Sp.l, Sp.s, Sp.l, 120), children: [
          Text('Your admin approves or rejects each request. Approved days show as absent on your calendar.'.tr, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          const SizedBox(height: Sp.m),
          if (sp.error != null) ErrorState(sp.error!.tr, sp.refresh),
          if (sp.leaves.isEmpty && sp.error == null) EmptyState(Icons.beach_access_outlined, 'No leave requests yet.'),
          for (final (i, l) in sp.leaves.indexed)
            Builder(builder: (_) {
              final (label, color, icon) = leaveStyle(l.status);
              return Padding(
                padding: const EdgeInsets.only(bottom: Sp.s),
                child: InfoCard(
                  leading: IconBadge(Icons.beach_access, color),
                  title: leaveRange(l),
                  subtitle: l.reason,
                  chips: [StatusChip(label.tr, color, icon: icon)],
                  trailing: l.pending
                      ? IconButton(
                          tooltip: 'Cancel request'.tr,
                          icon: const Icon(Icons.close),
                          onPressed: () async {
                            if (!await confirm(context, 'Cancel this request?', leaveRange(l), action: 'Cancel request', danger: true)) return;
                            try {
                              await sp.cancelLeave(l);
                            } catch (e) {
                              if (context.mounted) toast(context, 'Could not save: ${e.toString().replaceFirst('Exception: ', '')}', type: ToastType.error);
                            }
                          },
                        )
                      : null,
                ).enter(i),
              );
            }),
        ]),
      ),
    );
  }

  Future<void> _request(BuildContext context) async {
    final sp = context.read<StaffProvider>();
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: 'Choose leave dates'.tr,
    );
    if (range == null || !context.mounted) return;
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Request leave'.tr),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(leaveRange(LeaveRequest(id: '', from: range.start, to: range.end)), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: Sp.m),
          GlowTextField(controller: reason, maxLines: 3, textCapitalization: TextCapitalization.sentences, decoration: InputDecoration(labelText: 'Reason'.tr)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel'.tr)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(minimumSize: const Size(110, 44)), child: Text('Send request'.tr)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await sp.requestLeave(range.start, range.end, reason.text.trim());
      if (context.mounted) toast(context, 'Leave request sent to your admin', type: ToastType.success);
    } catch (e) {
      if (context.mounted) toast(context, 'Could not send: ${e.toString().replaceFirst('Exception: ', '')}', type: ToastType.error);
    }
  }
}
