import 'dart:async';

import 'package:cruisemonkey/src/progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ProgressValue - comparison', (WidgetTester tester) async {
    expect(const IdleProgress() < const IdleProgress(), isFalse);
    expect(const StartingProgress() < const StartingProgress(), isFalse);
    expect(const ActiveProgress(0.0, 1.0) < const ActiveProgress(0.0, 1.0), isFalse);
    expect(const FailedProgress(null) < const FailedProgress(null), isFalse);
    expect(const SuccessfulProgress<void>(null) < const SuccessfulProgress<void>(null), isFalse);
    expect(const IdleProgress() > const IdleProgress(), isFalse);
    expect(const StartingProgress() > const StartingProgress(), isFalse);
    expect(const ActiveProgress(0.0, 1.0) > const ActiveProgress(0.0, 1.0), isFalse);
    expect(const FailedProgress(null) > const FailedProgress(null), isFalse);
    expect(const SuccessfulProgress<void>(null) > const SuccessfulProgress<void>(null), isFalse);
    expect(const IdleProgress() <= const IdleProgress(), isTrue);
    expect(const StartingProgress() <= const StartingProgress(), isTrue);
    expect(const ActiveProgress(0.0, 1.0) <= const ActiveProgress(0.0, 1.0), isTrue);
    expect(const FailedProgress(null) <= const FailedProgress(null), isTrue);
    expect(const SuccessfulProgress<void>(null) <= const SuccessfulProgress<void>(null), isTrue);
    expect(const IdleProgress() >= const IdleProgress(), isTrue);
    expect(const StartingProgress() >= const StartingProgress(), isTrue);
    expect(const ActiveProgress(0.0, 1.0) >= const ActiveProgress(0.0, 1.0), isTrue);
    expect(const FailedProgress(null) >= const FailedProgress(null), isTrue);
    expect(const SuccessfulProgress<void>(null) >= const SuccessfulProgress<void>(null), isTrue);

    expect(const IdleProgress() < const StartingProgress(), isTrue);
    expect(const StartingProgress() < const ActiveProgress(0.0, 1.0), isTrue);
    expect(const ActiveProgress(0.0, 1.0) < const FailedProgress(null), isTrue);
    expect(const FailedProgress(null) < const SuccessfulProgress<void>(null), isTrue);

    expect(const StartingProgress() < const IdleProgress(), isFalse);
    expect(const ActiveProgress(0.0, 1.0) < const StartingProgress(), isFalse);
    expect(const FailedProgress(null) < const ActiveProgress(0.0, 1.0), isFalse);
    expect(const SuccessfulProgress<void>(null) < const FailedProgress(null), isFalse);

    expect(const IdleProgress() <= const StartingProgress(), isTrue);
    expect(const StartingProgress() <= const ActiveProgress(0.0, 1.0), isTrue);
    expect(const ActiveProgress(0.0, 1.0) <= const FailedProgress(null), isTrue);
    expect(const FailedProgress(null) <= const SuccessfulProgress<void>(null), isTrue);

    expect(const StartingProgress() <= const IdleProgress(), isFalse);
    expect(const ActiveProgress(0.0, 1.0) <= const StartingProgress(), isFalse);
    expect(const FailedProgress(null) <= const ActiveProgress(0.0, 1.0), isFalse);
    expect(const SuccessfulProgress<void>(null) <= const FailedProgress(null), isFalse);

    expect(const IdleProgress() > const StartingProgress(), isFalse);
    expect(const StartingProgress() > const ActiveProgress(0.0, 1.0), isFalse);
    expect(const ActiveProgress(0.0, 1.0) > const FailedProgress(null), isFalse);
    expect(const FailedProgress(null) > const SuccessfulProgress<void>(null), isFalse);

    expect(const StartingProgress() > const IdleProgress(), isTrue);
    expect(const ActiveProgress(0.0, 1.0) > const StartingProgress(), isTrue);
    expect(const FailedProgress(null) > const ActiveProgress(0.0, 1.0), isTrue);
    expect(const SuccessfulProgress<void>(null) > const FailedProgress(null), isTrue);

    expect(const IdleProgress() >= const StartingProgress(), isFalse);
    expect(const StartingProgress() >= const ActiveProgress(0.0, 1.0), isFalse);
    expect(const ActiveProgress(0.0, 1.0) >= const FailedProgress(null), isFalse);
    expect(const FailedProgress(null) >= const SuccessfulProgress<void>(null), isFalse);

    expect(const StartingProgress() >= const IdleProgress(), isTrue);
    expect(const ActiveProgress(0.0, 1.0) >= const StartingProgress(), isTrue);
    expect(const FailedProgress(null) >= const ActiveProgress(0.0, 1.0), isTrue);
    expect(const SuccessfulProgress<void>(null) >= const FailedProgress(null), isTrue);
  });

  testWidgets('Progress - fromFuture', (WidgetTester tester) async {
    final Completer<int> c = Completer<int>();
    final Progress<int> p = Progress<int>.fromFuture(c.future);
    expect(p.value, isInstanceOf<StartingProgress>());
    await tester.idle();
    expect(p.value, isInstanceOf<StartingProgress>());
    c.complete(2);
    expect(p.value, isInstanceOf<StartingProgress>());
    await tester.idle();
    expect(p.value, isInstanceOf<SuccessfulProgress<int>>());
  });

  testWidgets('ProgressController - advance, completeError', (WidgetTester tester) async {
    final ProgressController<int> c = ProgressController<int>();
    expect(c.progress.value, isInstanceOf<IdleProgress>());
    c.advance(1.0, 2.0);
    expect(c.progress.value, isInstanceOf<ActiveProgress>());
    expect((c.progress.value as ActiveProgress).progress, 1.0);
    expect((c.progress.value as ActiveProgress).target, 2.0);
    c.completeError('hello', null);
    expect(c.progress.value, isInstanceOf<FailedProgress>());
    expect((c.progress.value as FailedProgress).error.toString(), 'Exception: hello');
    expect((c.progress.value as FailedProgress).stackTrace, isNull);
  });

  testWidgets('ProgressController - start, completeError', (WidgetTester tester) async {
    final ProgressController<int> c = ProgressController<int>();
    expect(c.progress.value, isInstanceOf<IdleProgress>());
    c.start();
    expect(c.progress.value, isInstanceOf<StartingProgress>());
    final Exception e = Exception('world');
    c.completeError(e, null);
    expect(c.progress.value, isInstanceOf<FailedProgress>());
    expect((c.progress.value as FailedProgress).error, equals(e));
    expect((c.progress.value as FailedProgress).stackTrace, isNull);
  });
}