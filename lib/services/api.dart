import 'package:supabase_flutter/supabase_flutter.dart';

/// All data access goes through Postgres functions (see supabase/schema.sql).
class Api {
  static final _db = Supabase.instance.client;
  static String? _token;

  static Future<dynamic> _rpc(String fn, Map<String, dynamic> params) async {
    try {
      return await _db.rpc(fn, params: params);
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Network error. Check your connection.');
    }
  }

  static Future<Map<String, dynamic>> login(String email, String password, {required bool admin}) async {
    final res = await _rpc(admin ? 'admin_login' : 'user_login',
        {'p_email': email.trim(), 'p_password': password});
    final map = Map<String, dynamic>.from(res as Map);
    _token = map['token'] as String;
    return map;
  }

  static void logout() => _token = null;

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

  static Future<Map<String, dynamic>> createAdmin(String email, String? password) async {
    final res = await _rpc('admin_create_admin', {'p_token': _token, 'p_email': email, 'p_password': password});
    return Map<String, dynamic>.from(res as Map);
  }

  static Future<List<Map<String, dynamic>>> admins() async {
    final res = await _rpc('admin_list_admins', {'p_token': _token});
    return List<Map<String, dynamic>>.from(res as List);
  }

  static Future<void> deleteAdmin(String id) => _rpc('admin_delete_admin', {'p_token': _token, 'p_admin': id});
}
