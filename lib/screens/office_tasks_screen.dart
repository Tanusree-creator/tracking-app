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

/// Office staff: tasks without a location. Created by the employee or assigned by the admin.
class OfficeTasksScreen extends StatefulWidget {
  const OfficeTasksScreen({super.key});

  @override
  State<OfficeTasksScreen> createState() => _OfficeTasksScreenState();
}

class _OfficeTasksScreenState extends State<OfficeTasksScreen> {
  bool _showDone = false;

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<StaffProvider>();
    final list = sp.tasks.where((t) => t.done == _showDone).toList()..sort((a, b) => _showDone ? b.due.compareTo(a.due) : a.due.compareTo(b.due));
    return Scaffold(
      appBar: AppBar(title: Text('Tasks'.tr, style: const TextStyle(fontWeight: FontWeight.w700))),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 84),
        child: FloatingActionButton.extended(
          onPressed: () => showTaskSheet(context),
          icon: const Icon(Icons.add),
          label: Text('Add Task'.tr),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: sp.refresh,
        child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(Sp.l, 0, Sp.l, 130), children: [
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: false, label: Text('${'Open'.tr} (${sp.pendingTasks})')),
              ButtonSegment(value: true, label: Text('Done'.tr)),
            ],
            selected: {_showDone},
            onSelectionChanged: (s) => setState(() => _showDone = s.first),
          ),
          const SizedBox(height: Sp.m),
          if (sp.error != null) ErrorState(sp.error!.tr, sp.refresh),
          if (sp.loading && sp.tasks.isEmpty)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
          else if (list.isEmpty && sp.error == null)
            EmptyState(Icons.task_alt, _showDone ? 'Nothing finished yet.' : 'No open tasks. Add one, or wait for your admin to assign one.')
          else
            for (final (i, t) in list.indexed) Padding(padding: const EdgeInsets.only(bottom: Sp.s), child: OfficeTaskCard(t).enter(i)),
        ]),
      ),
    );
  }
}

class OfficeTaskCard extends StatelessWidget {
  final OfficeTask task;
  const OfficeTaskCard(this.task, {super.key});

  @override
  Widget build(BuildContext context) {
    final sp = context.read<StaffProvider>();
    final late = !task.done && task.due.isBefore(DateTime.now());
    final lang = L10n.current.name;
    return InfoCard(
      borderColor: late ? AppColors.red.withValues(alpha: .6) : null,
      leading: GestureDetector(
        onTap: () => _toggle(context, sp),
        child: IconBadge(task.done ? Icons.check_circle : Icons.radio_button_unchecked, task.done ? AppColors.green : AppColors.accent),
      ),
      title: task.title,
      subtitle: task.note,
      chips: [
        StatusChip(DateFormat('EEE d MMM · h:mm a', lang).format(task.due), late ? AppColors.red : AppColors.muted, icon: Icons.schedule),
        if (task.byAdmin) StatusChip('From admin'.tr, AppColors.accent, icon: Icons.admin_panel_settings_outlined),
        if (late) StatusChip('Overdue'.tr, AppColors.red),
        if (task.status == 'inProgress') StatusChip('In Progress'.tr, AppColors.amber),
      ],
      trailing: PopupMenuButton<String>(
        onSelected: (v) async {
          try {
            switch (v) {
              case 'start':
                await sp.setTaskStatus(task, 'inProgress');
              case 'done':
                await sp.setTaskStatus(task, 'completed');
              case 'reopen':
                await sp.setTaskStatus(task, 'pending');
              case 'edit':
                if (context.mounted) showTaskSheet(context, existing: task);
              case 'delete':
                if (await confirm(context, 'Delete task?', task.title, action: 'Delete', danger: true)) await sp.deleteTask(task);
            }
          } catch (e) {
            if (context.mounted) toast(context, 'Could not save: ${e.toString().replaceFirst('Exception: ', '')}', type: ToastType.error);
          }
        },
        itemBuilder: (_) => [
          if (!task.done && task.status != 'inProgress') PopupMenuItem(value: 'start', child: Text('Start'.tr)),
          if (!task.done) PopupMenuItem(value: 'done', child: Text('Mark done'.tr)) else PopupMenuItem(value: 'reopen', child: Text('Reopen'.tr)),
          if (!task.byAdmin) PopupMenuItem(value: 'edit', child: Text('Edit'.tr)),
          if (!task.byAdmin) PopupMenuItem(value: 'delete', child: Text('Delete'.tr)),
        ],
      ),
      onTap: task.byAdmin ? null : () => showTaskSheet(context, existing: task),
    );
  }

  Future<void> _toggle(BuildContext context, StaffProvider sp) async {
    try {
      await sp.setTaskStatus(task, task.done ? 'pending' : 'completed');
      if (context.mounted && task.done) toast(context, 'Task completed', type: ToastType.success);
    } catch (e) {
      if (context.mounted) toast(context, 'Could not save: ${e.toString().replaceFirst('Exception: ', '')}', type: ToastType.error);
    }
  }
}

void showTaskSheet(BuildContext context, {OfficeTask? existing}) {
  final sp = context.read<StaffProvider>();
  final title = TextEditingController(text: existing?.title);
  final note = TextEditingController(text: existing?.note);
  var due = existing?.due ?? DateTime.now().add(const Duration(hours: 2));
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
            Text((existing == null ? 'New Task' : 'Edit Task').tr, style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
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
                        if (existing == null) {
                          await sp.addTask(title.text.trim(), note.text.trim(), due);
                        } else {
                          existing
                            ..title = title.text.trim()
                            ..note = note.text.trim()
                            ..due = due;
                          await sp.saveTask(existing);
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        setState(() => busy = false);
                        if (ctx.mounted) toast(ctx, 'Could not save: ${e.toString().replaceFirst('Exception: ', '')}', type: ToastType.error);
                      }
                    },
              child: Text('Save'.tr),
            ),
          ]),
        ),
      ),
    ),
  );
}
