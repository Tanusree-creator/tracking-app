import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/access_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/glass.dart';

class AdminAccessScreen extends StatelessWidget {
  const AdminAccessScreen({super.key});

  Future<void> _decide(BuildContext context, Employee e, AccessStatus s) async {
    try {
      await context.read<AccessProvider>().setStatus(e, s);
      if (context.mounted) snack(context, '${e.name} ${s == AccessStatus.approved ? 'approved' : 'rejected'}');
    } catch (err) {
      if (context.mounted) snack(context, err.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = context.watch<AccessProvider>();
    final reqs = access.requests;
    return RefreshIndicator(
      onRefresh: access.refresh,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
        const SectionTitle('Pending Employee Requests'),
        if (access.loading && reqs.isEmpty)
          const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
        else if (access.error != null)
          ErrorState(access.error!, access.refresh)
        else if (reqs.isEmpty)
          const EmptyState(Icons.inbox_outlined, 'No pending requests right now.')
        else ...[
          const Text('Access Requests', style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 8),
          for (final r in reqs)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      CircleAvatar(backgroundColor: AppColors.surfaceHigh, child: Text(r.employee.initials)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(r.employee.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(r.employee.email, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _decide(context, r.employee, AccessStatus.rejected),
                          style: OutlinedButton.styleFrom(foregroundColor: AppColors.red, side: const BorderSide(color: AppColors.red)),
                          child: const Text('Reject'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _decide(context, r.employee, AccessStatus.approved),
                          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                          child: const Text('Approve'),
                        ),
                      ),
                    ]),
                  ]),
                ),
              ),
            ),
        ],
      ]),
    );
  }
}
