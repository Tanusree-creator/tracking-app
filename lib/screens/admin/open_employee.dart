import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../widgets/anim.dart';
import 'admin_employee_detail_screen.dart';
import 'admin_office_employee_screen.dart';

/// Marketing staff open the field detail (visits, routes); office staff open their tasks, calls and leave.
void openEmployee(BuildContext context, Employee e) =>
    Navigator.of(context).push(slideRoute(e.isOffice ? AdminOfficeEmployeeScreen(e) : AdminEmployeeDetailScreen(e)));
