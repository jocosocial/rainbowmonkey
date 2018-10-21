import 'package:flutter_test/flutter_test.dart';

import 'package:cruisemonkey/src/models/user.dart';

void main() {
  testWidgets('Credentials model', (WidgetTester tester) async {
    final Credentials a = new Credentials(
      username: 'a',
      password: 'b',
      key: 'c',
      loginTimestamp: DateTime(2000),
    );
    expect(a.username, 'a');
    expect(a.password, 'b');
    expect(a.key, 'c');
    expect(a.loginTimestamp, DateTime(2000));
    final Credentials b = a.copyWith();
    expect(b.username, 'a');
    expect(b.password, 'b');
    expect(b.key, 'c');
    expect(b.loginTimestamp, DateTime(2000));
    final Credentials c = a.copyWith(
      username: 'A',
      password: 'B',
      key: 'C',
      loginTimestamp: DateTime(2001),
    );
    expect(c.username, 'A');
    expect(c.password, 'B');
    expect(c.key, 'C');
    expect(c.loginTimestamp, DateTime(2001));
  });
  testWidgets('User model', (WidgetTester tester) async {
    const User a = User(
      username: 'u',
      email: 'e',
    );
    expect(a.username, 'u');
    expect(a.email, 'e');
    expect(a.credentials, isNull);
  });
  testWidgets('User.isValidUsername', (WidgetTester tester) async {
    expect(User.isValidUsername(''), isFalse);
    expect(User.isValidUsername('fo'), isFalse);
    expect(User.isValidUsername('foo'), isTrue);
    expect(User.isValidUsername(' foo'), isFalse);
    expect(User.isValidUsername('foo '), isFalse);
    expect(User.isValidUsername('f&o-o'), isTrue);
    expect(User.isValidUsername('f+o=o'), isFalse);
  });
  testWidgets('User.isValidPassword', (WidgetTester tester) async {
    expect(User.isValidPassword(''), isFalse);
    expect(User.isValidPassword('fo'), isFalse);
    expect(User.isValidPassword('foo'), isFalse);
    expect(User.isValidPassword(' foo'), isFalse);
    expect(User.isValidPassword('foo '), isFalse);
    expect(User.isValidPassword('f&o-o'), isFalse);
    expect(User.isValidPassword('      '), isTrue);
  });
  testWidgets('User.isValidDisplayName', (WidgetTester tester) async {
    expect(User.isValidDisplayName(null), isTrue);
    expect(User.isValidDisplayName(''), isFalse);
    expect(User.isValidDisplayName('fo'), isFalse);
    expect(User.isValidDisplayName('foo'), isTrue);
    expect(User.isValidDisplayName(' foo'), isTrue);
    expect(User.isValidDisplayName('foo '), isTrue);
    expect(User.isValidDisplayName('f&o-o'), isTrue);
    expect(User.isValidDisplayName('f+o=o'), isFalse);
    expect(User.isValidDisplayName('x' * 40), isTrue);
    expect(User.isValidDisplayName('x' * 41), isFalse);
  });
  testWidgets('User.isValidEmail', (WidgetTester tester) async {
    expect(User.isValidEmail(''), isFalse);
    expect(User.isValidEmail('test@example.com'), isTrue);
    expect(User.isValidEmail('test+foo@bar.example.test'), isTrue);
    expect(User.isValidEmail(' test@example.com'), isFalse);
    expect(User.isValidEmail('test@example.com '), isFalse);
    expect(User.isValidEmail('test%example.com'), isFalse);
    expect(User.isValidEmail('test@invalid'), isFalse);
    expect(User.isValidEmail('test @example.com'), isFalse);
    expect(User.isValidEmail('test@ example.com'), isFalse);
  });
  testWidgets('User.isValidSecurityQuestion', (WidgetTester tester) async {
    expect(User.isValidSecurityQuestion(''), isFalse);
    expect(User.isValidSecurityQuestion('a'), isTrue);
  });
  testWidgets('User.isValidSecurityAnswer', (WidgetTester tester) async {
    expect(User.isValidSecurityAnswer(''), isFalse);
    expect(User.isValidSecurityAnswer('a'), isTrue);
  });
}
