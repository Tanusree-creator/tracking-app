import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/access_provider.dart';
import '../services/api.dart';
import '../services/tracking_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';
import '../l10n/l10n.dart';

class _Row {
  final String id, name, title;
  final Uint8List? photo;
  final int done, onTime, copies, streak;
  _Row(this.id, this.name, this.title, this.photo, this.done, this.onTime, this.copies, this.streak);

  String get initials => name.split(' ').where((p) => p.isNotEmpty).take(2).map((p) => p[0].toUpperCase()).join();

  factory _Row.from(Map<String, dynamic> j) {
    final days = {for (final d in (j['days'] as List? ?? [])) DateTime.parse(d as String)};
    var d = DateTime.now();
    d = DateTime(d.year, d.month, d.day);
    if (!days.contains(d)) d = d.subtract(const Duration(days: 1));
    var streak = 0;
    while (days.contains(d)) {
      streak++;
      d = d.subtract(const Duration(days: 1));
    }
    Uint8List? photo;
    try {
      final a = j['avatar'] as String?;
      if (a != null && a.isNotEmpty) photo = base64Decode(a);
    } catch (_) {}
    return _Row(j['id'] as String, j['name'] as String, (j['role_title'] ?? '') as String, photo, (j['done'] as num).toInt(),
        (j['on_time'] as num).toInt(), (j['copies_ordered'] as num).toInt(), streak);
  }
}

const _gold = Color(0xFFF5B301), _silver = Color(0xFF9AA8C0), _bronze = Color(0xFFC77B3F);

/// This week's ranking by closed visits (ties: on-time starts). Shown to employees and admins.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late Future<List<_Row>> _f = _load();

  Future<List<_Row>> _load() async => (await Api.weeklyLeaderboard()).map(_Row.from).toList();

  Future<void> _setTarget() async {
    var current = context.read<TrackingProvider>().dailyTarget;
    try {
      current = await Api.dailyTarget();
    } catch (_) {}
    if (!mounted) return;
    final c = TextEditingController(text: '$current');
    final n = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Daily visit target'.tr),
        content: TextField(controller: c, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Visits per employee per day'.tr)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel'.tr)),
          FilledButton(onPressed: () => Navigator.pop(ctx, int.tryParse(c.text.trim())), style: FilledButton.styleFrom(minimumSize: const Size(90, 44)), child: Text('Save'.tr)),
        ],
      ),
    );
    if (n == null || !mounted) return;
    try {
      await Api.adminSetDailyTarget(n);
      if (!mounted) return;
      context.read<TrackingProvider>().dailyTarget = n;
      toast(context, trf('Daily target set to {} visits', [n]), type: ToastType.success);
    } catch (e) {
      if (mounted) toast(context, e.toString().replaceFirst('Exception: ', ''), type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = context.watch<AccessProvider>();
    final meId = access.me?.id;
    return Scaffold(
      appBar: AppBar(
        title: Text('Weekly leaderboard'.tr, style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if (access.isAdmin) IconButton(tooltip: 'Daily target'.tr, icon: const Icon(Icons.flag_outlined), onPressed: _setTarget),
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => setState(() => _f = _load())),
        ],
      ),
      body: FutureBuilder<List<_Row>>(
        future: _f,
        builder: (context, snap) {
          if (snap.hasError) {
            return ErrorState('${snap.error.toString().replaceFirst('Exception: ', '')}\n(Run supabase/006_outcomes_targets_leaderboard.sql if you have not yet.)',
                () => setState(() => _f = _load()));
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final rows = snap.data!;
          if (rows.isEmpty) return const EmptyState(Icons.emoji_events_outlined, 'No employees yet');
          final star = rows.first.done > 0 ? rows.first : null;
          return ListView(padding: Sp.screen, children: [
            Text('Monday to Sunday · ranked by visits closed, then on-time starts'.tr, style: TextStyle(color: AppColors.muted, fontSize: 13)),
            const SizedBox(height: Sp.m),
            if (star != null) _Star(star, isYou: star.id == meId),
            const SizedBox(height: Sp.m),
            for (final (i, r) in rows.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: Sp.s),
                child: _RankTile(i + 1, r, isYou: r.id == meId),
              ),
          ]);
        },
      ),
    );
  }
}

class _Star extends StatelessWidget {
  final _Row r;
  final bool isYou;
  const _Star(this.r, {required this.isYou});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Sp.l),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.blue600, AppColors.accent, AppColors.blue400]),
          border: Border.all(color: Colors.white.withValues(alpha: .45)),
          boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: .4), blurRadius: 24, offset: const Offset(0, 10))],
        ),
        child: Row(children: [
          UserAvatar(photo: r.photo, initials: r.initials, radius: 34, ring: _gold),
          const SizedBox(width: Sp.l),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.emoji_events, color: _gold, size: 18),
                SizedBox(width: 4),
                Text('EMPLOYEE OF THE WEEK'.tr, style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 1)),
              ]),
              const SizedBox(height: 2),
              Text(isYou ? '${r.name} (${'you'.tr})' : r.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 19)),
              Text(trf('{} closed this week', [trCount(r.done, 'visit', 'visits')]), style: const TextStyle(color: Colors.white70)),
            ]),
          ),
        ]),
      );
}

class _RankTile extends StatelessWidget {
  final int rank;
  final _Row r;
  final bool isYou;
  const _RankTile(this.rank, this.r, {required this.isYou});

  @override
  Widget build(BuildContext context) {
    final medal = rank == 1 ? _gold : rank == 2 ? _silver : rank == 3 ? _bronze : null;
    return GlassCard(
      borderColor: isYou ? AppColors.accent : null,
      borderWidth: isYou ? 1.6 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Sp.m, vertical: Sp.m),
        child: Row(children: [
          SizedBox(
            width: 34,
            child: medal != null
                ? Icon(Icons.workspace_premium, color: medal, size: 30)
                : Text('$rank', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.muted)),
          ),
          UserAvatar(photo: r.photo, initials: r.initials, radius: 21),
          const SizedBox(width: Sp.m),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isYou ? '${r.name} (${'you'.tr})' : r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Wrap(spacing: 6, runSpacing: 2, children: [
                if (r.onTime > 0) StatusChip(trf('{} on time', [r.onTime]), AppColors.green, icon: Icons.schedule),
                if (r.copies > 0) StatusChip(trf('{} copies', [r.copies]), AppColors.accent, icon: Icons.menu_book_outlined),
                if (r.streak >= 2) StatusChip(trf('{}-day streak', [r.streak]), AppColors.amber, icon: Icons.local_fire_department),
              ]),
            ]),
          ),
          Column(children: [
            Text('${r.done}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22)),
            Text('visits'.tr, style: TextStyle(color: AppColors.muted, fontSize: 11)),
          ]),
        ]),
      ),
    );
  }
}
