import '../models/user.dart';
import '../progress.dart';

enum Setting {
  server,
  debugNetworkLatency,
  debugNetworkReliability,
  debugTimeDilation,
}

abstract class DataStore {
  Progress<void> saveCredentials(Credentials value);
  Progress<Credentials> restoreCredentials();

  Progress<void> saveSetting(Setting id, dynamic value);
  Progress<Map<Setting, dynamic>> restoreSettings();

  // TODO(ianh): image cache for avatars
}
