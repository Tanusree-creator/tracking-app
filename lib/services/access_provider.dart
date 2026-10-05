import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'api.dart';
import 'demo_data.dart';

class AccessProvider extends ChangeNotifier {
  bool isAdmin = false;
  Employee? me; // signed-in employee (null for admin)
  String? adminEmail;

  List<Employee> _remote = [];
  bool loading = false;
  String? error;

  bool get signedIn => isAdmin || me != null;

  Future<void> login(String email, String password, {required bool admin}) async {
    final res = await Api.login(email, password, admin: admin);
    isAdmin = admin;
    adminEmail = admin ? res['email'] as String : null;
    me = admin
        ? null
        : Employee(
            id: res['id'] as String,
            name: res['name'] as String,
            email: res['email'] as String,
            title: (res['role_title'] ?? 'Field Technician') as String,
            district: (res['district'] ?? 'East District') as String,
          );
    notifyListeners();
    if (admin) await refresh();
  }

  Future<void> register(String name, String email, String password) =>
      Api.register(name.trim(), email.trim(), password);

  void logout() {
    Api.logout();
    isAdmin = false;
    me = null;
    _remote = [];
    notifyListeners();
  }

  // ── admin ──────────────────────────────────────────────────────────────────
  Future<void> refresh() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      _remote = (await Api.users()).map(Employee.fromRemote).toList();
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
    }
    loading = false;
    notifyListeners();
  }

  /// Demo roster + real approved accounts.
  List<Employee> get approved => [
        ...DemoData.employees,
        ..._remote.where((e) => e.access == AccessStatus.approved),
      ];

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
