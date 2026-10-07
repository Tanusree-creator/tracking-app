import 'package:flutter/material.dart';

import '../services/access_provider.dart';
import 'admin/admin_shell.dart';
import 'office_shell.dart';
import 'tech_shell.dart';

/// Which app opens after sign-in: admin, office staff (no tracking) or marketing staff (field app).
Widget homeFor(AccessProvider access) => access.isAdmin ? const AdminShell() : (access.isOffice ? const OfficeShell() : const TechShell());
