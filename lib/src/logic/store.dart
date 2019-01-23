import '../models/user.dart';
import '../progress.dart';

enum Setting {
  server,
  debugNetworkLatency,
  debugNetworkReliability,
  debugTimeDilation,
  notificationFreshnessToken,
}

typedef FreshnessCallback = Future<int> Function(int token);

abstract class DataStore {
  Progress<void> saveCredentials(Credentials value);
  Progress<Credentials> restoreCredentials();

  Progress<void> saveSetting(Setting id, dynamic value);
  Progress<Map<Setting, dynamic>> restoreSettings();
  Progress<dynamic> restoreSetting(Setting id);

  Future<void> addNotification(String threadId, String messageId);
  Future<void> removeNotification(String threadId, String messageId);
  Future<List<String>> getNotifications(String threadId);

  Future<void> updateFreshnessToken(FreshnessCallback callback);

  // TODO(ianh): image cache for avatars
}
