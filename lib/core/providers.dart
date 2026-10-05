import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'location/location_service.dart';
import 'notifications/notification_service.dart';
import 'storage/session_storage.dart';

final supabaseProvider = Provider<SupabaseClient>(
  (_) => Supabase.instance.client,
);

/// Overridden in main() once SharedPreferences is loaded.
final appPrefsProvider = Provider<AppPrefs>(
  (_) => throw UnimplementedError('appPrefsProvider not overridden'),
);

final locationServiceProvider = Provider((_) => LocationService());
final notificationServiceProvider = Provider((_) => NotificationService());
