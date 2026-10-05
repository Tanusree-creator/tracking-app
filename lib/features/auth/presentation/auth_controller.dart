import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider =
    Provider((ref) => AuthRepository(ref.watch(supabaseProvider)));

/// Current signed-in user (null = signed out). Restored from secure storage on start.
class AuthController extends Notifier<AppUser?> {
  @override
  AppUser? build() {
    final repo = ref.watch(authRepositoryProvider);
    final sub = repo.changes.listen((u) => state = u);
    ref.onDispose(sub.cancel);
    return repo.currentUser;
  }

  /// Returns an error message, or null on success.
  Future<String?> signIn(String email, String password) async {
    try {
      state = await ref.read(authRepositoryProvider).signIn(email, password);
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not reach the server. Check your connection.';
    }
  }

  Future<void> signOut() async {
    await ref.read(notificationServiceProvider).cancelAll();
    await ref.read(authRepositoryProvider).signOut();
    state = null;
  }
}

final authProvider = NotifierProvider<AuthController, AppUser?>(
  AuthController.new,
);
