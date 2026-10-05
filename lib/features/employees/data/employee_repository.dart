import 'package:supabase_flutter/supabase_flutter.dart';

class Employee {
  const Employee({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });
  final String id;
  final String name;
  final String email;
  final String role;

  factory Employee.fromRow(Map<String, dynamic> r) => Employee(
        id: r['id'] as String,
        name: (r['name'] ?? '') as String,
        email: (r['email'] ?? '') as String,
        role: (r['role'] ?? 'tech') as String,
      );
}

class EmployeeRepository {
  EmployeeRepository(this._db);
  final SupabaseClient _db;

  Future<List<Employee>> list() async {
    final rows = await _db.from('employees').select().order('name');
    return [for (final r in rows) Employee.fromRow(r)];
  }

  /// Admin only. The Edge Function checks the caller is an admin, then creates
  /// the Auth user with the service-role key (never shipped in the app).
  /// Throws [Exception] with a readable message.
  Future<void> create({
    required String name,
    required String email,
    required String password,
    String? phone,
    bool admin = false,
  }) async {
    try {
      final res = await _db.functions.invoke('create-employee', body: {
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
        'phone': phone?.trim(),
        'role': admin ? 'admin' : 'tech',
      });
      final data = res.data;
      if (data is Map && data['error'] != null) {
        throw Exception(data['error']);
      }
    } on FunctionException catch (e) {
      final d = e.details;
      throw Exception(d is Map && d['error'] != null
          ? d['error']
          : 'Could not create user (status ${e.status}).');
    }
  }
}
