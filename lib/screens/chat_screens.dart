import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/api.dart';
import '../services/tracking_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/anim.dart';
import '../widgets/common.dart';

/// Message thread. [mineIsAdmin] decides which side is "me".
class ChatView extends StatefulWidget {
  final Future<List<Map<String, dynamic>>> Function() load;
  final Future<void> Function(String) send;
  final bool mineIsAdmin;
  const ChatView({super.key, required this.load, required this.send, required this.mineIsAdmin});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  List<ChatMessage> _msgs = [];
  Timer? _timer;
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = (await widget.load()).map(ChatMessage.fromRemote).toList();
      if (!mounted) return;
      final grew = rows.length != _msgs.length;
      setState(() {
        _msgs = rows;
        _loading = false;
        _error = null;
      });
      if (grew) _toBottom();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = _msgs.isEmpty ? e.toString().replaceFirst('Exception: ', '') : null;
        });
      }
    }
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      });

  Future<void> _send() async {
    final t = _text.text.trim();
    if (t.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.send(t);
      _text.clear();
      await _load();
    } catch (e) {
      if (mounted) toast(context, 'Could not send: ${e.toString().replaceFirst('Exception: ', '')}', type: ToastType.error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(children: [
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ErrorState(_error!, _load)
                : _msgs.isEmpty
                    ? const EmptyState(Icons.chat_bubble_outline, 'No messages yet. Say hello.')
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        itemCount: _msgs.length,
                        itemBuilder: (_, i) {
                          final m = _msgs[i];
                          final mine = m.fromAdmin == widget.mineIsAdmin;
                          final showDay = i == 0 || !_sameDay(_msgs[i - 1].at, m.at);
                          return Column(children: [
                            if (showDay)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: Text(DateFormat('EEE, d MMM').format(m.at), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                              ),
                            if (m.isSystem)
                              _SystemLine(m)
                            else
                              _Bubble(m, mine: mine, dark: dark),
                          ]);
                        },
                      ),
      ),
      SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.edge(dark)))),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _text,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Message',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _sending ? null : _send,
              icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded),
            ),
          ]),
        ),
      ),
    ]);
  }
}

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

class _Bubble extends StatelessWidget {
  final ChatMessage m;
  final bool mine;
  final bool dark;
  const _Bubble(this.m, {required this.mine, required this.dark});

  @override
  Widget build(BuildContext context) => Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .78),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          decoration: BoxDecoration(
            color: mine ? AppColors.accent : (dark ? AppColors.blue800 : AppColors.blue50),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(mine ? 18 : 4),
              bottomRight: Radius.circular(mine ? 4 : 18),
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
            Align(alignment: Alignment.centerLeft, child: Text(m.body, style: TextStyle(color: mine ? Colors.white : null, fontSize: 15))),
            const SizedBox(height: 3),
            Text(DateFormat('h:mm a').format(m.at), style: TextStyle(fontSize: 10.5, color: mine ? Colors.white70 : AppColors.muted)),
          ]),
        ),
      );
}

class _SystemLine extends StatelessWidget {
  final ChatMessage m;
  const _SystemLine(this.m);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.bolt, size: 14, color: AppColors.accent),
            const SizedBox(width: 6),
            Flexible(child: Text('${m.body} · ${DateFormat('h:mm a').format(m.at)}', style: const TextStyle(fontSize: 12.5))),
          ]),
        ),
      );
}

/// Employee ↔ admin chat.
class EmployeeChatScreen extends StatelessWidget {
  const EmployeeChatScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Chat with admin', style: TextStyle(fontWeight: FontWeight.w700))),
        body: ChatView(
          mineIsAdmin: false,
          load: () async {
            final r = await Api.myChat();
            // opening the thread marks messages read
            if (context.mounted) context.read<TrackingProvider>().unreadChat = 0;
            return r;
          },
          send: Api.sendChat,
        ),
      );
}

/// Admin: every employee's thread, newest first.
class AdminChatListScreen extends StatefulWidget {
  const AdminChatListScreen({super.key});

  @override
  State<AdminChatListScreen> createState() => _AdminChatListScreenState();
}

class _AdminChatListScreenState extends State<AdminChatListScreen> {
  List<Map<String, dynamic>>? _threads;
  String? _error;
  Timer? _timer;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final t = await Api.adminChatThreads();
      if (mounted) {
        setState(() {
          _threads = t;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && _threads == null) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return ErrorState('$_error\n(Run supabase/004_field_sync.sql if you have not yet.)', _load);
    final all = _threads;
    if (all == null) return const Center(child: CircularProgressIndicator());
    final list = all.where((t) => (t['name'] as String).toLowerCase().contains(_q.toLowerCase())).toList();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: TextField(
          onChanged: (v) => setState(() => _q = v),
          decoration: const InputDecoration(hintText: 'Search employees', prefixIcon: Icon(Icons.search)),
        ),
      ),
      Expanded(
        child: list.isEmpty
            ? const EmptyState(Icons.forum_outlined, 'No employees to chat with yet.')
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final t = list[i];
                  final unread = (t['unread'] as num).toInt();
                  final at = t['last_at'] == null ? null : DateTime.parse(t['last_at'] as String).toLocal();
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                          backgroundColor: AppColors.accent,
                          child: Text((t['name'] as String).substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                      title: Text(t['name'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text((t['last_body'] ?? 'No messages yet') as String, maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                        if (at != null) Text(DateFormat(_sameDay(at, DateTime.now()) ? 'h:mm a' : 'd MMM').format(at), style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                        if (unread > 0) ...[
                          const SizedBox(height: 4),
                          Badge(label: Text('$unread'), backgroundColor: AppColors.accent),
                        ],
                      ]),
                      onTap: () async {
                        await Navigator.of(context).push(slideRoute(AdminChatThreadScreen(t['id'] as String, t['name'] as String)));
                        _load();
                      },
                    ),
                  );
                },
              ),
      ),
    ]);
  }
}

class AdminChatThreadScreen extends StatelessWidget {
  final String userId;
  final String name;
  const AdminChatThreadScreen(this.userId, this.name, {super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700))),
        body: ChatView(
          mineIsAdmin: true,
          load: () => Api.adminChat(userId),
          send: (b) => Api.adminSendChat(userId, b),
        ),
      );
}
