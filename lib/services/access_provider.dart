import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'api.dart';

class AccessProvider extends ChangeNotifier {
  bool isAdmin = false;
  Employee? me; // signed-in employee (null for admin)
  String? adminEmail;

  List<Employee> _remote = [];
  bool loading = false;
  DateTime? lastUpdated;
  String? error;

  bool get signedIn => isAdmin || me != null;
  bool hasFace = false; // an enrolled reference photo exists on the server

  List<Employee> _live = [];

  /// Profile photos, decoded once. `myAvatar` is the signed-in employee's; `avatars` is every employee's (admin).
  Uint8List? myAvatar;
  Map<String, Uint8List> avatars = {};

  Uint8List? avatarOf(String id) => avatars[id];

  static Uint8List? _decode(String? b64) {
    if (b64 == null || b64.isEmpty) return null;
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadMyProfile() async {
    try {
      final p = await Api.myProfile();
      myAvatar = _decode(p['avatar'] as String?);
      final m = me;
      if (m != null) {
        me = Employee(id: m.id, name: p['name'] as String, email: m.email, title: (p['role_title'] ?? m.title) as String, district: m.district, phone: p['phone'] as String?);
      }
      notifyListeners();
    } catch (_) {} // 005_profile_photo_map.sql not run yet: keep initials
  }

  /// Re-open the saved session without asking for a password. Returns true if one was restored.
  Future<bool> restore() async {
    final s = await Api.restoreSession();
    if (s == null) return false;
    _applySession(s, admin: s['role'] == 'admin');
    notifyListeners();
    if (isAdmin) {
      refresh();
    } else {
      _loadMyProfile();
    }
    return true;
  }

  void _applySession(Map<String, dynamic> res, {required bool admin}) {
    isAdmin = admin;
    adminEmail = admin ? res['email'] as String : null;
    hasFace = res['has_face'] == true;
    me = admin
        ? null
        : Employee(
            id: res['id'] as String,
            name: res['name'] as String,
            email: res['email'] as String,
            title: (res['role_title'] ?? 'Field Technician') as String,
            district: (res['district'] ?? 'East District') as String,
          );
  }

  Future<void> login(String email, String password, {required bool admin}) async {
    final res = await Api.login(email, password, admin: admin);
    if (!admin) {
      // has_face comes from session_info
      try {
        res['has_face'] = (await Api.restoreSession())?['has_face'] == true;
      } catch (_) {}
    }
    _applySession(res, admin: admin);
    notifyListeners();
    if (admin) {
      await refresh();
    } else {
      _loadMyProfile();
    }
  }

  Future<void> register(String name, String email, String password) =>
      Api.register(name.trim(), email.trim(), password);

  Future<void> logout() async {
    await Api.logout();
    isAdmin = false;
    me = null;
    myAvatar = null;
    avatars = {};
    _remote = [];
    _live = [];
    notifyListeners();
  }

  /// [avatarB64]: null keeps the photo, '' removes it.
  Future<void> updateProfile(String name, String phone, String title, String? avatarB64) async {
    final res = await Api.updateProfile(name, phone, title, avatarB64);
    final m = me!;
    me = Employee(
        id: m.id, name: res['name'] as String, email: m.email, title: (res['role_title'] ?? m.title) as String, district: m.district, phone: res['phone'] as String?);
    if (avatarB64 != null) myAvatar = _decode(res['avatar'] as String?);
    notifyListeners();
  }

  // ── admin ──────────────────────────────────────────────────────────────────
  Future<void> refresh({bool silent = false}) async {
    if (!silent) {
      loading = true;
      error = null;
      notifyListeners();
    }
    try {
      _remote = (await Api.users()).map(Employee.fromRemote).toList();
      try {
        _live = (await Api.adminLive()).map(Employee.fromLive).toList();
      } catch (_) {
        _live = []; // 004_field_sync.sql not run yet: fall back to the plain roster
      }
      lastUpdated = DateTime.now();
      if (!silent || avatars.isEmpty) {
        try {
          avatars = {for (final e in (await Api.adminAvatars()).entries) if (_decode(e.value) != null) e.key: _decode(e.value)!};
        } catch (_) {} // 005_profile_photo_map.sql not run yet
      }
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
    }
    loading = false;
    notifyListeners();
  }

  /// Approved accounts, with live duty/position when available.
  List<Employee> get approved =>
      _live.isNotEmpty ? _live : _remote.where((e) => e.access == AccessStatus.approved).toList();

  List<AccessRequest> get requests => _remote
      .where((e) => e.access == AccessStatus.pending)
      .map((e) => AccessRequest(e, DateTime.now()))
      .toList();

  Future<void> setStatus(Employee e, AccessStatus s) async {
    await Api.setStatus(e.id, s.name);
    await refresh();
  }

  Future<Map<String, dynamic>> createUser(String name, String email, String? password) async {
    final res = await Api.createUser(name, email, password);
    await refresh();
    return res;
  }
}
