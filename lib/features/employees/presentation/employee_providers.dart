import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/employee_repository.dart';

final employeeRepositoryProvider =
    Provider((ref) => EmployeeRepository(ref.watch(supabaseProvider)));

final employeesProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(employeeRepositoryProvider).list(),
);
