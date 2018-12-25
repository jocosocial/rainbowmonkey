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

class HttpServerError implements Exception {
  const HttpServerError(this.statusCode, this.reasonPhrase, this.url);

  final int statusCode;
  final String reasonPhrase;
  final Uri url;

  @override
  String toString() {
    switch (statusCode) {
      case 500:
      case 501:
      case 502:
      case 503:
      case 504: return 'Server is having problems (it said "$reasonPhrase"). Try again later.';
      case 401:
      case 403: return 'There was an authentication problem (server said "$reasonPhrase"). Try logging in again.';
      case 400:
      case 405: return 'There is probably a bug (server said "$reasonPhrase"). Try again, maybe?';
      default: return 'There was an unexpected error. The server said "$statusCode $reasonPhrase" in response to a request to: $url';
    }
  }
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

  double get debugLatency;
  set debugLatency(double value);

  double get debugReliability;
  set debugReliability(double value);

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
