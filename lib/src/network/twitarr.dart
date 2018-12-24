import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../logic/photo_manager.dart';
import '../models/calendar.dart';
import '../models/seamail.dart';
import '../models/user.dart';
import '../progress.dart';

class ServerError implements Exception {
  const ServerError(this.messages);

  final List<String> messages;

  @override
  String toString() => messages.join('\n');
}

class InvalidUsernameOrPasswordError implements Exception {
  const InvalidUsernameOrPasswordError();

  @override
  String toString() => 'Server did not recognize the username or password.';
}

@immutable
abstract class TwitarrConfiguration {
  const TwitarrConfiguration();
  Twitarr createTwitarr();
}

class CancelationSignal {
  bool get canceled => _canceled;
  bool _canceled = false;
  void cancel() {
    _canceled = true;
  }
}

/// An interface for communicating with the server.
abstract class Twitarr {
  const Twitarr();

  TwitarrConfiguration get configuration;

  Progress<AuthenticatedUser> createAccount({
    @required String username,
    @required String password,
    @required String email,
    @required String securityQuestion,
    @required String securityAnswer,
  });

  Progress<AuthenticatedUser> login({
    @required String username,
    @required String password,
    @required PhotoManager photoManager,
  });
  Progress<AuthenticatedUser> logout();

  Progress<AuthenticatedUser> getAuthenticatedUser(Credentials credentials, PhotoManager photoManager);
  Progress<Calendar> getCalendar();

  Future<void> updateSeamailThreads(
    Credentials credentials,
    Seamail seamail,
    PhotoManager photoManager,
    CancelationSignal cancelationSignal,
  );

  Progress<SeamailThread> newSeamail(
    Credentials credentials,
    Seamail seamail,
    PhotoManager photoManager,
    Set<User> users,
    String subject,
    String message,
  );

  Progress<Uint8List> fetchProfilePicture(String username);

  Progress<List<User>> getUserList(String searchTerm);

  void dispose();
}
