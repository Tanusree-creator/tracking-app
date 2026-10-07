import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NetworkException implements Exception {
  @override
  String toString() => 'Exception: Network error. Check your connection.';
}

/// All data access goes through Postgres functions (see supabase/schema.sql, 004_field_sync.sql).
class Api {
  static final _db = Supabase.instance.client;
  static const _store = FlutterSecureStorage();
  static String? _token;

  static String? get token => _token;

  static Future<dynamic> _rpc(String fn, Map<String, dynamic> params) async {
    try {
      return await _db.rpc(fn, params: params);
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw NetworkException();
    }
  }

  // ── stay signed in ─────────────────────────────────────────────────────────
  static Future<void> _persist(Map<String, dynamic> session) async {
    try {
      await _store.write(key: 'session', value: jsonEncode(session));
    } catch (_) {}
  }

  /// Returns the saved session (revalidated with the server) or null if the user must sign in.
  /// If the server can't be reached the cached session is returned, so the app opens offline.
  static Future<Map<String, dynamic>?> restoreSession() async {
    try {
      final raw = await _store.read(key: 'session');
      if (raw == null) return null;
      final saved = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      _token = saved['token'] as String?;
      if (_token == null) return null;
      try {
        final info = Map<String, dynamic>.from(await _rpc('session_info', {'p_token': _token}) as Map);
        final merged = {...saved, ...info};
        await _persist(merged);
        return merged;
      } on NetworkException {
        return saved;
      } catch (_) {
        await clearSession();
        return null;
      }
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearSession() async {
    _token = null;
    try {
      await _store.delete(key: 'session');
    } catch (_) {}
  }

  static Future<Map<String, dynamic>> login(String email, String password, {required bool admin}) async {
    final res = await _rpc(admin ? 'admin_login' : 'user_login',
        {'p_email': email.trim(), 'p_password': password});
    final map = Map<String, dynamic>.from(res as Map);
    _token = map['token'] as String;
    await _persist(map);
    return map;
  }

  static Future<void> logout() async {
    final t = _token;
    await clearSession();
    if (t != null) {
      try {
        await _rpc('sign_out', {'p_token': t});
      } catch (_) {}
    }
  }

  static Future<void> register(String name, String email, String password) =>
      _rpc('register_employee', {'p_name': name, 'p_email': email, 'p_password': password});

  static Future<Map<String, dynamic>> createUser(String name, String email, String? password) async {
    final res = await _rpc('admin_create_user',
        {'p_token': _token, 'p_name': name, 'p_email': email, 'p_password': password});
    return Map<String, dynamic>.from(res as Map);
  }

  static Future<List<Map<String, dynamic>>> users() async {
    final res = await _rpc('admin_list_users', {'p_token': _token});
    return List<Map<String, dynamic>>.from(res as List);
  }

  static Future<void> setStatus(String userId, String status) =>
      _rpc('admin_set_user_status', {'p_token': _token, 'p_user': userId, 'p_status': status});

  static Future<List<Map<String, dynamic>>> messages() async {
    final res = await _rpc('my_messages', {'p_token': _token});
    return List<Map<String, dynamic>>.from(res as List);
  }

  static Future<Map<String, dynamic>> myProfile() async =>
      Map<String, dynamic>.from(await _rpc('my_profile', {'p_token': _token}) as Map);

  /// [avatar]: null keeps the current photo, '' removes it, otherwise a base64 JPEG.
  static Future<Map<String, dynamic>> updateProfile(String name, String phone, String title, String? avatar) async =>
      Map<String, dynamic>.from(await _rpc('update_my_profile_v2',
          {'p_token': _token, 'p_name': name, 'p_phone': phone, 'p_title': title, 'p_avatar': avatar}) as Map);

  /// id -> base64 photo for every employee that has one (admin only).
  static Future<Map<String, String>> adminAvatars() async {
    final rows = List<Map<String, dynamic>>.from(await _rpc('admin_avatars', {'p_token': _token}) as List);
    return {for (final r in rows) r['id'] as String: r['avatar'] as String};
  }

  static Future<List<Map<String, dynamic>>> adminTasksRange(DateTime from, DateTime to) async =>
      List<Map<String, dynamic>>.from(await _rpc('admin_tasks_range', {
        'p_token': _token,
        'p_from': from.toUtc().toIso8601String(),
        'p_to': to.toUtc().toIso8601String(),
      }) as List);

  static Future<List<Map<String, dynamic>>> adminTaskPins() async =>
      List<Map<String, dynamic>>.from(await _rpc('admin_task_pins', {'p_token': _token}) as List);

  static Future<Map<String, dynamic>> createAdmin(String email, String? password) async {
    final res = await _rpc('admin_create_admin', {'p_token': _token, 'p_email': email, 'p_password': password});
    return Map<String, dynamic>.from(res as Map);
  }

  static Future<List<Map<String, dynamic>>> admins() async {
    final res = await _rpc('admin_list_admins', {'p_token': _token});
    return List<Map<String, dynamic>>.from(res as List);
  }

  static Future<void> deleteAdmin(String id) => _rpc('admin_delete_admin', {'p_token': _token, 'p_admin': id});

  // ── face checks ────────────────────────────────────────────────────────────
  static Future<void> logFace(String kind, String photoB64) =>
      _rpc('log_face_check', {'p_token': _token, 'p_kind': kind, 'p_photo': photoB64});

  // ── employee field data ────────────────────────────────────────────────────
  static Future<void> syncShift(Map<String, dynamic> s) => _rpc('sync_shift', {
        'p_token': _token,
        'p_id': s['id'],
        'p_start': s['start'],
        'p_end': s['end'],
        'p_breaks': s['breaks'],
      });

  static Future<void> syncVisit(Map<String, dynamic> v) async {
    final base = {
      'p_token': _token,
      'p_id': v['id'],
      'p_title': v['title'],
      'p_location': v['location'],
      'p_lat': v['lat'],
      'p_lng': v['lng'],
      'p_scheduled': v['scheduled'],
      'p_status': v['status'],
      'p_started': v['started'],
      'p_completed': v['completed'],
      'p_photo': v['photo'],
    };
    try {
      await _rpc('sync_visit_v2', {...base, 'p_outcome': v['outcome'], 'p_note': v['note'], 'p_copies': v['copies']});
    } on Exception catch (e) {
      // 006 not run yet: save the visit without its outcome.
      if (!e.toString().contains('sync_visit_v2')) rethrow;
      await _rpc('sync_visit', base);
    }
  }

  static Future<int> dailyTarget() async => (await _rpc('get_daily_target', {'p_token': _token}) as num).toInt();

  static Future<void> adminSetDailyTarget(int n) => _rpc('admin_set_daily_target', {'p_token': _token, 'p_target': n});

  static Future<List<Map<String, dynamic>>> weeklyLeaderboard() async =>
      List<Map<String, dynamic>>.from(await _rpc('weekly_leaderboard', {'p_token': _token}) as List);

  static Future<List<Map<String, dynamic>>> myVisits() async =>
      List<Map<String, dynamic>>.from(await _rpc('my_visits', {'p_token': _token}) as List);

  static Future<List<Map<String, dynamic>>> myShifts() async =>
      List<Map<String, dynamic>>.from(await _rpc('my_shifts', {'p_token': _token}) as List);

  static Future<void> addPoints(List<Map<String, dynamic>> pts) =>
      _rpc('add_location_points', {'p_token': _token, 'p_points': pts});

  static Future<List<Map<String, dynamic>>> myRoute(DateTime from, DateTime to) async =>
      List<Map<String, dynamic>>.from(await _rpc('my_route', {
        'p_token': _token,
        'p_from': from.toUtc().toIso8601String(),
        'p_to': to.toUtc().toIso8601String(),
      }) as List);

  // ── chat ───────────────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> myChat() async =>
      List<Map<String, dynamic>>.from(await _rpc('my_chat', {'p_token': _token}) as List);

  static Future<int> myUnreadChat() async => (await _rpc('my_unread_chat', {'p_token': _token}) as num).toInt();

  static Future<void> sendChat(String body) => _rpc('send_chat', {'p_token': _token, 'p_body': body});

  // ── admin ──────────────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> adminLive() async =>
      List<Map<String, dynamic>>.from(await _rpc('admin_live', {'p_token': _token}) as List);

  static Future<Map<String, dynamic>> adminEmployeeData(String userId) async =>
      Map<String, dynamic>.from(await _rpc('admin_employee_data', {'p_token': _token, 'p_user': userId}) as Map);

  static Future<Map<String, dynamic>> adminReportData(DateTime from, DateTime to) async =>
      Map<String, dynamic>.from(await _rpc('admin_report_data', {
        'p_token': _token,
        'p_from': from.toUtc().toIso8601String(),
        'p_to': to.toUtc().toIso8601String(),
      }) as Map);

  static Future<List<Map<String, dynamic>>> adminRoute(String userId, DateTime from, DateTime to) async =>
      List<Map<String, dynamic>>.from(await _rpc('admin_route', {
        'p_token': _token,
        'p_user': userId,
        'p_from': from.toUtc().toIso8601String(),
        'p_to': to.toUtc().toIso8601String(),
      }) as List);

  static Future<String?> adminVisitPhoto(String visitId) async =>
      await _rpc('admin_visit_photo', {'p_token': _token, 'p_visit': visitId}) as String?;

  static Future<String?> adminFacePhoto(String checkId) async =>
      await _rpc('admin_face_photo', {'p_token': _token, 'p_check': checkId}) as String?;

  static Future<void> adminCreateTask(String userId, String title, String location, double lat, double lng, DateTime when) =>
      _rpc('admin_create_task', {
        'p_token': _token,
        'p_user': userId,
        'p_title': title,
        'p_location': location,
        'p_lat': lat,
        'p_lng': lng,
        'p_when': when.toUtc().toIso8601String(),
      });

  static Future<List<Map<String, dynamic>>> adminChatThreads() async =>
      List<Map<String, dynamic>>.from(await _rpc('admin_chat_threads', {'p_token': _token}) as List);

  static Future<List<Map<String, dynamic>>> adminChat(String userId) async =>
      List<Map<String, dynamic>>.from(await _rpc('admin_chat', {'p_token': _token, 'p_user': userId}) as List);

  static Future<void> adminSendChat(String userId, String body) =>
      _rpc('admin_send_chat', {'p_token': _token, 'p_user': userId, 'p_body': body});

  static Future<List<Map<String, dynamic>>> adminEventsSince(DateTime since) async =>
      List<Map<String, dynamic>>.from(await _rpc('admin_events_since', {
        'p_token': _token,
        'p_since': since.toUtc().toIso8601String(),
      }) as List);
}
