import 'package:flutter/foundation.dart';

import '../models/calendar.dart';
import '../models/user.dart';
import '../progress.dart';

class ServerError implements Exception {
  ServerError(this.messages);

  final List<String> messages;

  @override
  String toString() => messages.join('\n');
}

class InvalidUsernameOrPasswordError implements Exception {
  const InvalidUsernameOrPasswordError();

  @override
  String toString() => 'Server did not recognize the username or password.';
}

/// An interface for communicating with the server.
abstract class Twitarr {
  Progress<User> createAccount({
    @required String username,
    @required String password,
    @required String email,
    @required String securityQuestion,
    @required String securityAnswer,
  });

  Progress<User> login({
    @required String username,
    @required String password,
  });
  Progress<User> logout();

  Progress<User> getAuthenticatedUser(Credentials credentials);
  Progress<Calendar> getCalendar();

  void dispose();
}
