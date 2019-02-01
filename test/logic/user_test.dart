import 'package:flutter_test/flutter_test.dart';

import 'package:cruisemonkey/src/models/user.dart';

void main() {
  testWidgets('Credentials model', (WidgetTester tester) async {
    final Credentials a = Credentials(
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
  testWidgets('AuthenticatedUser model', (WidgetTester tester) async {
    const AuthenticatedUser a = AuthenticatedUser(
      username: 'u',
      email: 'e',
    );
    expect(a.username, 'u');
    expect(a.email, 'e');
    expect(a.credentials, isNull);
  });
  testWidgets('AuthenticatedUser.isValidUsername', (WidgetTester tester) async {
    expect(AuthenticatedUser.isValidUsername(''), isFalse);
    expect(AuthenticatedUser.isValidUsername('fo'), isFalse);
    expect(AuthenticatedUser.isValidUsername('foo'), isTrue);
    expect(AuthenticatedUser.isValidUsername(' foo'), isFalse);
    expect(AuthenticatedUser.isValidUsername('foo '), isFalse);
    expect(AuthenticatedUser.isValidUsername('f&o-o'), isTrue);
    expect(AuthenticatedUser.isValidUsername('f+o=o'), isFalse);
  });
  testWidgets('AuthenticatedUser.isValidPassword', (WidgetTester tester) async {
    expect(AuthenticatedUser.isValidPassword(''), isFalse);
    expect(AuthenticatedUser.isValidPassword('fo'), isFalse);
    expect(AuthenticatedUser.isValidPassword('foo'), isFalse);
    expect(AuthenticatedUser.isValidPassword(' foo'), isFalse);
    expect(AuthenticatedUser.isValidPassword('foo '), isFalse);
    expect(AuthenticatedUser.isValidPassword('f&o-o'), isFalse);
    expect(AuthenticatedUser.isValidPassword('      '), isTrue);
  });
  testWidgets('AuthenticatedUser.isValidDisplayName', (WidgetTester tester) async {
    expect(AuthenticatedUser.isValidDisplayName(null), isTrue);
    expect(AuthenticatedUser.isValidDisplayName(''), isFalse);
    expect(AuthenticatedUser.isValidDisplayName('fo'), isFalse);
    expect(AuthenticatedUser.isValidDisplayName('foo'), isTrue);
    expect(AuthenticatedUser.isValidDisplayName(' foo'), isTrue);
    expect(AuthenticatedUser.isValidDisplayName('foo '), isTrue);
    expect(AuthenticatedUser.isValidDisplayName('f&o-o'), isTrue);
    expect(AuthenticatedUser.isValidDisplayName('f+o=o'), isFalse);
    expect(AuthenticatedUser.isValidDisplayName('x' * 40), isTrue);
    expect(AuthenticatedUser.isValidDisplayName('x' * 41), isFalse);
  });
  testWidgets('AuthenticatedUser.isValidEmail', (WidgetTester tester) async {
    expect(AuthenticatedUser.isValidEmail(''), isTrue);
    expect(AuthenticatedUser.isValidEmail(' '), isFalse);
    expect(AuthenticatedUser.isValidEmail('test@example.com'), isTrue);
    expect(AuthenticatedUser.isValidEmail('test+foo@bar.example.test'), isTrue);
    expect(AuthenticatedUser.isValidEmail(' test@example.com'), isFalse);
    expect(AuthenticatedUser.isValidEmail('test@example.com '), isFalse);
    expect(AuthenticatedUser.isValidEmail('test%example.com'), isFalse);
    expect(AuthenticatedUser.isValidEmail('test@invalid'), isTrue);
    expect(AuthenticatedUser.isValidEmail('test @example.com'), isFalse);
    expect(AuthenticatedUser.isValidEmail('test@ example.com'), isFalse);
  });
}
