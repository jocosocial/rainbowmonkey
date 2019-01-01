import 'package:android_alarm_manager/android_alarm_manager.dart';
import 'package:flutter/foundation.dart';

void runBackground() async {
  return;
  if (!await AndroidAlarmManager.initialize()) { // ignore: dead_code
    FlutterError.reportError(FlutterErrorDetails(
      exception: Exception('Android Alarm Manager failed to start up.'),
      library: 'Cruisemonkey',
      context: 'during startup',
    ));
    return;
  }
  await AndroidAlarmManager.periodic(const Duration(minutes: 2), 0, _update);
}

void _update() async {
  print('background update...');
}
