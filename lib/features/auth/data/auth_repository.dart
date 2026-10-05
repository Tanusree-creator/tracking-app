import 'package:supabase_flutter/supabase_flutter.dart';

enum UserRole { admin, tech }

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.role,
    this.name,
  });

  final String id;
  final String email;
  final UserRole role;
  final String? name;

  bool get isAdmin => role == UserRole.admin;

  factory AppUser.fromAuth(User u) => AppUser(
        id: u.id,
        email: u.email ?? '',
        role: u.appMetadata['role'] == 'admin' ? UserRole.admin : UserRole.tech,
        name: u.userMetadata?['name'] as String?,
      );
}

class AuthRepository {
  AuthRepository(this._client);
  final SupabaseClient _client;

  AppUser? get currentUser {
    final u = _client.auth.currentUser;
    return u == null ? null : AppUser.fromAuth(u);
  }

  Stream<AppUser?> get changes => _client.auth.onAuthStateChange.map(
        (e) => e.session == null ? null : AppUser.fromAuth(e.session!.user),
      );

  /// Throws [AuthException] with a readable message on failure.
  Future<AppUser> signIn(String email, String password) async {
    final res = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    return AppUser.fromAuth(res.user!);
  }

  Future<void> signOut() => _client.auth.signOut();
}
