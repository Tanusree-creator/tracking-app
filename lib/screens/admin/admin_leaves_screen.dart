import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../models/office_models.dart';
import '../../services/access_provider.dart';
import '../../services/api.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/glass.dart';
import '../../widgets/pickers.dart';
import '../leave_screen.dart' show leaveRange, leaveStyle;

/// Leave requests from marketing and office staff. Approving marks those days absent on the calendar.
class AdminLeavesScreen extends StatefulWidget {
  const AdminLeavesScreen({super.key});

  @override
  State<AdminLeavesScreen> createState() => _AdminLeavesScreenState();
}

class _AdminLeavesScreenState extends State<AdminLeavesScreen> {
  List<LeaveRequest>? _all;
  String? _error;
  final _busy = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = (await Api.adminLeaves()).map(LeaveRequest.fromRemote).toList();
      if (mounted) {
        setState(() {
          _all = rows;
          _error = null;
        });
        context.read<AccessProvider>().setPendingLeaves(rows.where((l) => l.pending).length);
      }
    } catch (e) {
      if (mounted) setState(() => _error = '${e.toString().replaceFirst('Exception: ', '')}\n(Run supabase/007_office_leaves_announcements.sql if you have not yet.)');
    }
  }

  Future<void> _decide(LeaveRequest l, bool approve) async {
    setState(() => _busy.add(l.id));
    try {
      await Api.adminDecideLeave(l.id, approve);
      await _load();
      if (mounted) toast(context, approve ? 'Leave approved' : 'Leave rejected', type: ToastType.success);
    } catch (e) {
      if (mounted) toast(context, 'Could not save: ${e.toString().replaceFirst('Exception: ', '')}', type: ToastType.error);
    } finally {
      if (mounted) setState(() => _busy.remove(l.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = _all;
    return Scaffold(
      appBar: AppBar(title: Text('Leave requests'.tr, style: const TextStyle(fontWeight: FontWeight.w700))),
      body: _error != null
          ? ErrorState(_error!, _load)
          : all == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(Sp.l, 0, Sp.l, 48), children: [
                    if (all.isEmpty) EmptyState(Icons.beach_access_outlined, 'No leave requests yet.'),
                    if (all.any((l) => l.pending)) SectionTitle('Waiting for you'.tr),
                    for (final (i, l) in all.where((l) => l.pending).indexed) Padding(padding: const EdgeInsets.only(bottom: Sp.s), child: _tile(l, true).enter(i)),
                    if (all.any((l) => !l.pending)) SectionTitle('Decided'.tr),
                    for (final l in all.where((l) => !l.pending)) Padding(padding: const EdgeInsets.only(bottom: Sp.s), child: _tile(l, false)),
                  ]),
                ),
    );
  }

  Widget _tile(LeaveRequest l, bool actions) {
    final (label, color, icon) = leaveStyle(l.status);
    final busy = _busy.contains(l.id);
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(Sp.m),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            IconBadge(Icons.beach_access, color),
            const SizedBox(width: Sp.m),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.userName ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                Text(leaveRange(l), style: const TextStyle(fontWeight: FontWeight.w600)),
              ]),
            ),
            StatusChip(label.tr, color, icon: icon),
          ]),
          if (l.reason.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(l.reason)),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              (l.staffType == 'office' ? 'Office staff' : 'Marketing staff').tr,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
          if (actions)
            Padding(
              padding: const EdgeInsets.only(top: Sp.m),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : () => _decide(l, false),
                    icon: const Icon(Icons.close, color: AppColors.red),
                    label: Text('Reject'.tr, style: const TextStyle(color: AppColors.red)),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46), side: const BorderSide(color: AppColors.red)),
                  ),
                ),
                const SizedBox(width: Sp.m),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy ? null : () => _decide(l, true),
                    icon: const Icon(Icons.check),
                    label: Text('Approve'.tr),
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 46), backgroundColor: AppColors.green),
                  ),
                ),
              ]),
            )
          else if (l.decidedAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(DateFormat('d MMM y · h:mm a', L10n.current.name).format(l.decidedAt!), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ),
        ]),
      ),
    );
  }
}
