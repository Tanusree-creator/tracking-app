import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/office_models.dart';
import '../services/api.dart';
import '../services/staff_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';

class AnnouncementCard extends StatelessWidget {
  final Announcement a;
  final VoidCallback? onDelete;
  final String? audienceLabel;
  const AnnouncementCard(this.a, {super.key, this.onDelete, this.audienceLabel});

  @override
  Widget build(BuildContext context) {
    Uint8List? img;
    if (a.image != null && a.image!.isNotEmpty) {
      try {
        img = base64Decode(a.image!);
      } catch (_) {}
    }
    return GlassCard(
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (img != null) ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(20)), child: Image.memory(img, width: double.infinity, height: 180, fit: BoxFit.cover)),
        Padding(
          padding: const EdgeInsets.all(Sp.l),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.campaign, color: AppColors.accent),
              const SizedBox(width: 8),
              Expanded(child: Text(a.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5))),
              if (onDelete != null) IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.delete_outline, color: AppColors.red), onPressed: onDelete),
            ]),
            if (a.body.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(a.body)),
            const SizedBox(height: 8),
            Text('${DateFormat('d MMM y · h:mm a', L10n.current.name).format(a.at)}${audienceLabel == null ? '' : ' · $audienceLabel'}', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ]),
        ),
      ]),
    );
  }
}

/// Employee: announcements from the admin, newest first.
class AnnouncementsScreen extends StatelessWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<StaffProvider>();
    return Scaffold(
      appBar: AppBar(title: Text('Announcements'.tr, style: const TextStyle(fontWeight: FontWeight.w700))),
      body: RefreshIndicator(
        onRefresh: sp.refresh,
        child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(Sp.l, Sp.s, Sp.l, 48), children: [
          if (sp.error != null) ErrorState(sp.error!.tr, sp.refresh),
          if (sp.announcements.isEmpty && sp.error == null) EmptyState(Icons.campaign_outlined, 'No announcements yet.'),
          for (final a in sp.announcements) Padding(padding: const EdgeInsets.only(bottom: Sp.m), child: AnnouncementCard(a)),
        ]),
      ),
    );
  }
}

/// Admin: write an announcement for everyone, or just marketing / office staff.
class AdminAnnouncementsScreen extends StatefulWidget {
  const AdminAnnouncementsScreen({super.key});

  @override
  State<AdminAnnouncementsScreen> createState() => _AdminAnnouncementsScreenState();
}

class _AdminAnnouncementsScreenState extends State<AdminAnnouncementsScreen> {
  List<Announcement>? _list;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = (await Api.adminAnnouncements()).map(Announcement.fromRemote).toList();
      if (mounted) {
        setState(() {
          _list = rows;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '${e.toString().replaceFirst('Exception: ', '')}\n(Run supabase/007_office_leaves_announcements.sql if you have not yet.)');
    }
  }

  String _audience(String a) => switch (a) {
        'field' => 'Marketing staff'.tr,
        'office' => 'Office staff'.tr,
        _ => 'Everyone'.tr,
      };

  @override
  Widget build(BuildContext context) {
    final list = _list;
    return Scaffold(
      appBar: AppBar(title: Text('Announcements'.tr, style: const TextStyle(fontWeight: FontWeight.w700))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _compose,
        icon: const Icon(Icons.campaign),
        label: Text('New announcement'.tr),
      ),
      body: _error != null
          ? ErrorState(_error!, _load)
          : list == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(Sp.l, Sp.s, Sp.l, 120), children: [
                    if (list.isEmpty) EmptyState(Icons.campaign_outlined, 'No announcements yet.'),
                    for (final a in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Sp.m),
                        child: AnnouncementCard(
                          a,
                          audienceLabel: _audience(a.audience),
                          onDelete: () async {
                            final ok = await confirm(context, 'Delete announcement?', a.title, action: 'Delete', danger: true);
                            if (!ok) return;
                            try {
                              await Api.adminDeleteAnnouncement(a.id);
                              _load();
                            } catch (e) {
                              if (mounted) toast(this.context, 'Could not delete: ${e.toString().replaceFirst('Exception: ', '')}', type: ToastType.error);
                            }
                          },
                        ),
                      ),
                  ]),
                ),
    );
  }

  void _compose() {
    final title = TextEditingController();
    final body = TextEditingController();
    String audience = 'all';
    String? image;
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
              Text('New announcement'.tr, style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: Sp.l),
              GlowTextField(controller: title, textCapitalization: TextCapitalization.sentences, decoration: InputDecoration(labelText: 'Title'.tr), validator: (v) => (v ?? '').trim().isEmpty ? 'Required'.tr : null),
              const SizedBox(height: Sp.m),
              GlowTextField(controller: body, textCapitalization: TextCapitalization.sentences, maxLines: 5, decoration: InputDecoration(labelText: 'Message'.tr)),
              const SizedBox(height: Sp.m),
              Text('Send to'.tr, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: Sp.s),
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: 'all', label: Text('Everyone'.tr)),
                  ButtonSegment(value: 'field', label: Text('Marketing'.tr)),
                  ButtonSegment(value: 'office', label: Text('Office'.tr)),
                ],
                selected: {audience},
                onSelectionChanged: (s) => setState(() => audience = s.first),
              ),
              const SizedBox(height: Sp.m),
              if (image != null)
                Stack(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.memory(base64Decode(image!), width: double.infinity, height: 150, fit: BoxFit.cover)),
                  Positioned(top: 6, right: 6, child: IconButton.filled(onPressed: () => setState(() => image = null), icon: const Icon(Icons.close))),
                ])
              else
                OutlinedButton.icon(
                  onPressed: () async {
                    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1000, imageQuality: 70);
                    if (x == null) return;
                    final bytes = await x.readAsBytes();
                    setState(() => image = base64Encode(bytes));
                  },
                  icon: const Icon(Icons.image_outlined),
                  label: Text('Add a picture (optional)'.tr),
                ),
              const SizedBox(height: Sp.xl),
              FilledButton.icon(
                onPressed: busy
                    ? null
                    : () async {
                        if (!form.currentState!.validate()) return;
                        setState(() => busy = true);
                        try {
                          await Api.adminCreateAnnouncement(title.text.trim(), body.text.trim(), image, audience);
                          if (ctx.mounted) Navigator.pop(ctx);
                          _load();
                          if (!mounted) return;
                          // ignore: use_build_context_synchronously
                          toast(context, 'Announcement sent', type: ToastType.success);
                        } catch (e) {
                          setState(() => busy = false);
                          if (ctx.mounted) toast(ctx, 'Could not send: ${e.toString().replaceFirst('Exception: ', '')}', type: ToastType.error);
                        }
                      },
                icon: const Icon(Icons.send),
                label: Text('Send'.tr),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
