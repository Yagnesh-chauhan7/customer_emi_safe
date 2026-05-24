import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_version_model.dart';
import '../config/app_constants.dart';

class UpdateService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Checks if an update is available by querying `customer_app_versions`.
  /// Returns [AppVersionModel] if a newer version exists, otherwise returns null.
  static Future<AppVersionModel?> checkForUpdate() async {
    try {
      final response = await _supabase
          .from('customer_app_versions')
          .select()
          .order('id', ascending: false)
          .limit(1);

      if (response.isNotEmpty) {
        final latestVersion = AppVersionModel.fromJson(response.first);
        if (latestVersion.version != AppConstants.currentAppVersion) {
          return latestVersion;
        }
      }
      return null;
    } catch (e) {
      return null; // Fail gracefully if network issue
    }
  }
}
