import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

import '../l10n/l10n.dart';

import '../models/models.dart';
import '../services/api.dart';
import '../services/tracking_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/anim.dart';
import '../widgets/common.dart';

/// Message thread. [mineIsAdmin] decides which side is "me". Besides text it can carry photos and voice notes.
class ChatView extends StatefulWidget {
  final Future<List<Map<String, dynamic>>> Function() load;
  final Future<void> Function(String) send;
  final Future<void> Function(String kind, String base64) sendMedia;
  final Future<String?> Function(String id) loadMedia;
  final bool mineIsAdmin;
  const ChatView({super.key, required this.load, required this.send, required this.sendMedia, required this.loadMedia, required this.mineIsAdmin});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  final _recorder = AudioRecorder();
  List<ChatMessage> _msgs = [];
  final _media = <String, Uint8List>{}; // fetched photos / voice notes, kept for the life of the screen
  Timer? _timer;
  Timer? _recTimer;
  bool _loading = true;
  bool _sending = false;
  bool _recording = false;
  bool _hasText = false;
  int _recSeconds = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _load());
    _text.addListener(() {
      final has = _text.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recTimer?.cancel();
    _recorder.dispose();
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

  void _fail(Object e) {
    if (mounted) toast(context, '${'Could not send'.tr}: ${e.toString().replaceFirst('Exception: ', '')}', type: ToastType.error);
  }

  Future<void> _send() async {
    final t = _text.text.trim();
    if (t.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.send(t);
      _text.clear();
      await _load();
    } catch (e) {
      _fail(e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ── photos ──────────────────────────────────────────────────────────────────
  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: Text('Take a photo'.tr), onTap: () => Navigator.pop(ctx, ImageSource.camera)),
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: Text('Choose from gallery'.tr), onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
        ]),
      ),
    );
    if (source == null) return;
    try {
      final shot = await ImagePicker().pickImage(source: source, maxWidth: 1280, imageQuality: 70);
      if (shot == null) return;
      setState(() => _sending = true);
      await widget.sendMedia('image', base64Encode(await shot.readAsBytes()));
      await _load();
    } catch (e) {
      _fail(e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ── voice notes ─────────────────────────────────────────────────────────────
  Future<void> _startRecording() async {
    try {
      if (!await _recorder.hasPermission()) {
        if (mounted) toast(context, 'Allow microphone access to send voice messages.'.tr, type: ToastType.error);
        return;
      }
      final dir = await getTemporaryDirectory();
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 48000, sampleRate: 22050, numChannels: 1), path: '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a');
      _recSeconds = 0;
      _recTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _recSeconds++);
        if (_recSeconds >= 120) _stopRecording(send: true); // keeps the upload small
      });
      setState(() => _recording = true);
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> _stopRecording({required bool send}) async {
    _recTimer?.cancel();
    final secs = _recSeconds;
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {}
    if (mounted) setState(() => _recording = false);
    if (path == null) return;
    final file = File(path);
    try {
      if (!send || secs < 1) return;
      setState(() => _sending = true);
      await widget.sendMedia('voice', base64Encode(await file.readAsBytes()));
      await _load();
    } catch (e) {
      _fail(e);
    } finally {
      if (mounted) setState(() => _sending = false);
      file.delete().catchError((_) => file);
    }
  }

  /// Photo or audio bytes of a message, downloaded once.
  Future<Uint8List?> _bytes(String id) async {
    final have = _media[id];
    if (have != null) return have;
    final b64 = await widget.loadMedia(id);
    if (b64 == null || b64.isEmpty) return null;
    return _media[id] = base64Decode(b64);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(children: [
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ErrorState(_error!.tr, _load)
                : _msgs.isEmpty
                    ? EmptyState(Icons.chat_bubble_outline, 'No messages yet. Say hello.')
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
                                child: Text(DateFormat('EEE, d MMM', L10n.current.name).format(m.at), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                              ),
                            if (m.isSystem)
                              _SystemLine(m)
                            else
                              _Bubble(m, mine: mine, dark: dark, bytes: _bytes),
                          ]);
                        },
                      ),
      ),
      SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.edge(dark)))),
          child: _recording ? _recordingBar() : _composer(),
        ),
      ),
    ]);
  }

  Widget _recordingBar() => Row(children: [
        IconButton(tooltip: 'Cancel'.tr, icon: const Icon(Icons.delete_outline, color: AppColors.red), onPressed: () => _stopRecording(send: false)),
        const Icon(Icons.fiber_manual_record, color: AppColors.red, size: 16),
        const SizedBox(width: 8),
        Text('${(_recSeconds ~/ 60).toString().padLeft(2, '0')}:${(_recSeconds % 60).toString().padLeft(2, '0')}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(width: 10),
        Expanded(child: Text('Recording…'.tr, style: const TextStyle(color: AppColors.muted))),
        IconButton.filled(onPressed: () => _stopRecording(send: true), icon: const Icon(Icons.send_rounded)),
      ]);

  Widget _composer() => Row(children: [
        IconButton(tooltip: 'Photo'.tr, onPressed: _sending ? null : _pickPhoto, icon: const Icon(Icons.add_photo_alternate_outlined)),
        Expanded(
          child: TextField(
            controller: _text,
            minLines: 1,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Message'.tr,
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
            ),
            onSubmitted: (_) => _send(),
          ),
        ),
        const SizedBox(width: 8),
        if (_sending)
          const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)))
        else if (_hasText)
          IconButton.filled(onPressed: _send, icon: const Icon(Icons.send_rounded))
        else
          IconButton.filled(tooltip: 'Record a voice message'.tr, onPressed: _startRecording, icon: const Icon(Icons.mic)),
      ]);
}

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

class _Bubble extends StatelessWidget {
  final ChatMessage m;
  final bool mine;
  final bool dark;
  final Future<Uint8List?> Function(String id) bytes;
  const _Bubble(this.m, {required this.mine, required this.dark, required this.bytes});

  @override
  Widget build(BuildContext context) {
    final fg = mine ? Colors.white : null;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .78),
        padding: EdgeInsets.fromLTRB(m.isImage ? 5 : 14, m.isImage ? 5 : 10, m.isImage ? 5 : 14, 8),
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
          if (m.isImage)
            _PhotoBubble(m.id, bytes)
          else if (m.isVoice)
            _VoiceBubble(m.id, bytes, mine: mine)
          else
            Align(alignment: Alignment.centerLeft, child: Text(m.body, style: TextStyle(color: fg, fontSize: 15))),
          const SizedBox(height: 3),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: m.isImage ? 8 : 0),
            child: Text(DateFormat('h:mm a', L10n.current.name).format(m.at), style: TextStyle(fontSize: 10.5, color: mine ? Colors.white70 : AppColors.muted)),
          ),
        ]),
      ),
    );
  }
}

class _PhotoBubble extends StatelessWidget {
  final String id;
  final Future<Uint8List?> Function(String id) bytes;
  const _PhotoBubble(this.id, this.bytes);

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
        future: bytes(id),
        builder: (_, snap) {
          final b = snap.data;
          if (b == null) {
            return SizedBox(
              width: 200,
              height: 150,
              child: Center(child: snap.connectionState == ConnectionState.done ? const Icon(Icons.broken_image_outlined) : const CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          return GestureDetector(
            onTap: () => Navigator.of(context).push(PageRouteBuilder(
              opaque: false,
              barrierColor: Colors.black,
              pageBuilder: (_, _, _) => Scaffold(
                backgroundColor: Colors.black,
                appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
                body: Center(child: InteractiveViewer(child: Image.memory(b))),
              ),
            )),
            child: ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.memory(b, width: 220, fit: BoxFit.cover)),
          );
        },
      );
}

class _VoiceBubble extends StatefulWidget {
  final String id;
  final Future<Uint8List?> Function(String id) bytes;
  final bool mine;
  const _VoiceBubble(this.id, this.bytes, {required this.mine});

  @override
  State<_VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<_VoiceBubble> {
  AudioPlayer? _player;
  bool _loading = false;
  bool _playing = false;
  Duration _pos = Duration.zero;
  Duration _len = Duration.zero;

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_loading) return;
    if (_playing) {
      await _player?.pause();
      return;
    }
    if (_player == null) {
      setState(() => _loading = true);
      try {
        final b = await widget.bytes(widget.id);
        if (b == null) throw Exception('Voice message not found');
        final p = AudioPlayer();
        p.onPlayerStateChanged.listen((s) {
          if (mounted) setState(() => _playing = s == PlayerState.playing);
        });
        p.onPositionChanged.listen((d) {
          if (mounted) setState(() => _pos = d);
        });
        p.onDurationChanged.listen((d) {
          if (mounted) setState(() => _len = d);
        });
        p.onPlayerComplete.listen((_) {
          if (mounted) setState(() => _pos = Duration.zero);
        });
        await p.setSource(BytesSource(b, mimeType: 'audio/mp4'));
        _player = p;
      } catch (e) {
        if (mounted) toast(context, 'Could not play: ${e.toString().replaceFirst('Exception: ', '')}', type: ToastType.error);
        return;
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
    await _player!.resume();
  }

  static String _fmt(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final fg = widget.mine ? Colors.white : AppColors.accent;
    final progress = _len.inMilliseconds == 0 ? 0.0 : (_pos.inMilliseconds / _len.inMilliseconds).clamp(0.0, 1.0);
    return SizedBox(
      width: 210,
      child: Row(children: [
        _loading
            ? Padding(padding: const EdgeInsets.all(10), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: fg)))
            : IconButton(onPressed: _toggle, icon: Icon(_playing ? Icons.pause_circle_filled : Icons.play_circle_fill, size: 36, color: fg)),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: progress, minHeight: 4, color: fg, backgroundColor: fg.withValues(alpha: .25)),
            ),
            const SizedBox(height: 4),
            Text(_len == Duration.zero ? 'Voice message'.tr : _fmt(_playing || _pos > Duration.zero ? _pos : _len), style: TextStyle(fontSize: 12, color: widget.mine ? Colors.white70 : AppColors.muted)),
          ]),
        ),
      ]),
    );
  }
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
            Flexible(child: Text('${m.body.tr} · ${DateFormat('h:mm a').format(m.at)}', style: const TextStyle(fontSize: 12.5))),
          ]),
        ),
      );
}

/// Employee ↔ admin chat.
class EmployeeChatScreen extends StatelessWidget {
  const EmployeeChatScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('Chat with admin'.tr, style: TextStyle(fontWeight: FontWeight.w700))),
        body: ChatView(
          mineIsAdmin: false,
          load: () async {
            final r = await Api.myChat();
            // opening the thread marks messages read
            if (context.mounted) context.read<TrackingProvider>().unreadChat = 0;
            return r;
          },
          send: Api.sendChat,
          sendMedia: Api.sendChatMedia,
          loadMedia: Api.chatMedia,
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
          decoration: InputDecoration(hintText: 'Search employees'.tr, prefixIcon: Icon(Icons.search)),
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
                      subtitle: Text(((t['last_body'] ?? 'No messages yet') as String).tr, maxLines: 1, overflow: TextOverflow.ellipsis),
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
          sendMedia: (k, m) => Api.adminSendChatMedia(userId, k, m),
          loadMedia: Api.adminChatMedia,
        ),
      );
}
