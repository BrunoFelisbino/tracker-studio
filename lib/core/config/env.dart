import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppEnv {
  const AppEnv._();

  static const apiBaseUrl = String.fromEnvironment('TRACKER_STUDIO_API_BASE_URL');
}

final authEnabledProvider = Provider<bool>((ref) => false);
