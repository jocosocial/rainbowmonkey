import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:cruisemonkey/src/progress.dart';

void main() {
  testWidgets('PollingValueNotifier', (WidgetTester tester) async {
    int value = 0;
    final PollingValueNotifier<int> notifier = new PollingValueNotifier<int>(
      interval: const Duration(seconds: 10),
      getter: () {
        final CompleterWithProgress<int> completer = new CompleterWithProgress<int>()
          ..startProgress();
        new Timer(const Duration(seconds: 1), () {
          completer.complete(value++);
        });
        return completer.future;
      },
    );
    final List<String> log = <String>[];
    void listener() {
      log.add('${notifier.progressStatus} ${notifier.value}');
    }
    notifier.addListener(listener);
    await tester.pump();
    expect(log, <String>[]);
    await tester.pump(const Duration(milliseconds: 600)); // 0.6s
    expect(log, <String>[]);
    await tester.pump(const Duration(milliseconds: 600)); // 1.2s
    expect(log, <String>['ProgressStatus.complete 0']);
    await tester.pump(const Duration(milliseconds: 600)); // 1.8s
    expect(log, <String>['ProgressStatus.complete 0']);
    await tester.pump(const Duration(seconds: 8)); // 9.8s
    expect(log, <String>['ProgressStatus.complete 0']);
    await tester.pump(const Duration(milliseconds: 600)); // 10.4s
    expect(log, <String>['ProgressStatus.complete 0', 'ProgressStatus.updating 0']);
    await tester.pump(const Duration(milliseconds: 800)); // 11.2s
    expect(log, <String>['ProgressStatus.complete 0', 'ProgressStatus.updating 0', 'ProgressStatus.complete 1']);
    await tester.pump(const Duration(milliseconds: 600)); // 11.8s
    expect(log, <String>['ProgressStatus.complete 0', 'ProgressStatus.updating 0', 'ProgressStatus.complete 1']);
    notifier.removeListener(listener);
  });
}
