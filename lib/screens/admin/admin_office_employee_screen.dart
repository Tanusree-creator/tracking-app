import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../models/models.dart';
import '../../models/office_models.dart';
import '../../services/access_provider.dart';
import '../../services/api.dart';
import '../../services/calendar_loaders.dart';
import '../../theme/app_theme.dart';
import '../../widgets/anim.dart';
import '../../widgets/avatar.dart';
import '../../widgets/common.dart';
import '../../widgets/glass.dart';
import '../../widgets/pickers.dart';
import '../calendar_screen.dart';
import '../chat_screens.dart';
import '../leave_screen.dart' show leaveRange, leaveStyle;

/// One office (in-house) employee: their tasks, calls and leave. No routes or attendance clock (they are not tracked).
class AdminOfficeEmployeeScreen extends StatefulWidget {
  final Employee employee;
  const AdminOfficeEmployeeScreen(this.employee, {super.key});

  @override
  State<AdminOfficeEmployeeScreen> createState() => _AdminOfficeEmployeeScreenState();
}

class _AdminOfficeEmployeeScreenState extends State<AdminOfficeEmployeeScreen> {
  List<OfficeTask> _tasks = [];
  List<FollowUp> _calls = [];
  List<LeaveRequest> _leaves = [];
  bool _loading = true;
  String? _error;

  Employee get e => widget.employee;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final t = (await Api.adminOfficeTasks(e.id)).map(OfficeTask.fromRemote).toList();
      final c = (await Api.adminFollowUps(e.id)).map(FollowUp.fromRemote).toList();
      final l = (await Api.adminLeaves(e.id)).map(LeaveRequest.fromRemote).toList();
      if (mounted) {
        setState(() {
          _tasks = t;
          _calls = c;
          _leaves = l;
          _loading = false;
          _error = null;
        });
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '${err.toString().replaceFirst('Exception: ', '')}\n(Run supabase/007_office_leaves_announcements.sql if you have not yet.)';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = L10n.current.name;
    final fmt = DateFormat('EEE d MMM · h:mm a', lang);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(e.name),
          actions: [
            IconButton(
              tooltip: 'Calendar'.tr,
              icon: const Icon(Icons.calendar_month_outlined),
              onPressed: () => Navigator.of(context).push(slideRoute(CalendarScreen(showWho: false, loader: (f, t) => adminCalendarItems(f, t, e.id)))),
            ),
            IconButton(
              tooltip: 'Message'.tr,
              icon: const Icon(Icons.chat_bubble_outline),
              onPressed: () => Navigator.of(context).push(slideRoute(AdminChatThreadScreen(e.id, e.name))),
            ),
          ],
        ),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(children: [
              UserAvatar(photo: context.watch<AccessProvider>().avatarOf(e.id), initials: e.initials, radius: 30, ring: AppColors.accent),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e.email, style: const TextStyle(color: AppColors.muted), overflow: TextOverflow.ellipsis),
                  Text('${e.title} · ${'Office staff'.tr}', style: const TextStyle(color: AppColors.muted)),
                  if (e.phone != null) Text(e.phone!, style: const TextStyle(color: AppColors.muted)),
                ]),
              ),
              FilledButton.icon(
                onPressed: _assign,
                icon: const Icon(Icons.add_task, size: 18),
                label: Text('Task'.tr),
                style: FilledButton.styleFrom(minimumSize: const Size(90, 42)),
              ),
            ]),
          ),
          TabBar(tabs: [Tab(text: 'Tasks'.tr), Tab(text: 'Calls'.tr), Tab(text: 'Leave'.tr)]),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? ErrorState(_error!, _load)
                    : TabBarView(children: [
                        _list(_tasks.isEmpty ? null : [
                          for (final t in _tasks)
                            InfoCard(
                              leading: IconBadge(t.done ? Icons.check_circle : Icons.radio_button_unchecked, t.done ? AppColors.green : AppColors.accent),
                              title: t.title,
                              subtitle: t.note,
                              chips: [StatusChip(fmt.format(t.due), AppColors.muted, icon: Icons.schedule), StatusChip((t.done ? 'Done' : 'Open').tr, t.done ? AppColors.green : AppColors.amber)],
                            ),
                        ], Icons.task_alt, 'No tasks yet.'),
                        _list(_calls.isEmpty ? null : [
                          for (final f in _calls)
                            InfoCard(
                              leading: IconBadge(f.isCall ? Icons.phone_in_talk : Icons.storefront, f.done ? AppColors.muted : const Color(0xFF7C4DFF)),
                              title: f.org.isEmpty ? f.name : '${f.name} · ${f.org}',
                              subtitle: f.done && f.result.isNotEmpty ? f.result : f.purpose,
                              chips: [
                                StatusChip(fmt.format(f.remindAt), f.overdue ? AppColors.red : AppColors.muted, icon: Icons.schedule),
                                StatusChip((f.isCall ? 'Call' : 'Visit').tr, const Color(0xFF7C4DFF)),
                                if (f.done) StatusChip('Done'.tr, AppColors.green),
                              ],
                            ),
                        ], Icons.phone_in_talk_outlined, 'No calls planned.'),
                        _list(_leaves.isEmpty ? null : [
                          for (final l in _leaves)
                            Builder(builder: (_) {
                              final (label, color, icon) = leaveStyle(l.status);
                              return InfoCard(
                                leading: IconBadge(Icons.beach_access, color),
                                title: leaveRange(l),
                                subtitle: l.reason,
                                chips: [StatusChip(label.tr, color, icon: icon)],
                              );
                            }),
                        ], Icons.beach_access_outlined, 'No leave requests yet.'),
                      ]),
          ),
        ]),
      ),
    );
  }

  Widget _list(List<Widget>? items, IconData icon, String empty) => RefreshIndicator(
        onRefresh: _load,
        child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(Sp.l, Sp.s, Sp.l, 48), children: [
          if (items == null) EmptyState(icon, empty),
          for (final (i, w) in (items ?? const <Widget>[]).indexed) Padding(padding: const EdgeInsets.only(bottom: Sp.s), child: w.enter(i)),
        ]),
      );

  void _assign() {
    final title = TextEditingController();
    final note = TextEditingController();
    var due = DateTime.now().add(const Duration(hours: 3));
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
              Text('${'Assign task to'.tr} ${e.name.split(' ').first}', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: Sp.l),
              GlowTextField(controller: title, textCapitalization: TextCapitalization.sentences, decoration: InputDecoration(labelText: 'Task'.tr), validator: (v) => (v ?? '').trim().isEmpty ? 'Required'.tr : null),
              const SizedBox(height: Sp.m),
              GlowTextField(controller: note, textCapitalization: TextCapitalization.sentences, maxLines: 3, decoration: InputDecoration(labelText: 'Note (optional)'.tr)),
              const SizedBox(height: Sp.m),
              DateTimeField(label: 'Due'.tr, value: due, onChanged: (d) => setState(() => due = d)),
              const SizedBox(height: Sp.xl),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        if (!form.currentState!.validate()) return;
                        setState(() => busy = true);
                        try {
                          await Api.adminCreateOfficeTask(e.id, title.text.trim(), note.text.trim(), due);
                          if (ctx.mounted) Navigator.pop(ctx);
                          _load();
                          if (mounted) toast(context, 'Task created', type: ToastType.success);
                        } catch (err) {
                          setState(() => busy = false);
                          if (ctx.mounted) toast(ctx, 'Could not save: ${err.toString().replaceFirst('Exception: ', '')}', type: ToastType.error);
                        }
                      },
                child: Text('Assign'.tr),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
