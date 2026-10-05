import 'package:flutter_test/flutter_test.dart';
import 'package:trackingapp/features/auth/data/auth_repository.dart';

void main() {
  test('UserRole enum has admin and tech', () {
    expect(UserRole.values, containsAll([UserRole.admin, UserRole.tech]));
  });
}
