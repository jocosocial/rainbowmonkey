import 'dart:ui' show hashValues;

import 'package:flutter/foundation.dart';

@immutable
class Credentials {
  const Credentials({
    this.username,
    this.password,
    this.key,
    this.loginTimestamp,
  });

  Credentials copyWith({
    String username,
    String password,
    String key,
    DateTime loginTimestamp,
  }) {
    return new Credentials(
      username: username ?? this.username,
      password: password ?? this.password,
      key: key ?? this.key,
      loginTimestamp: loginTimestamp ?? this.loginTimestamp,
    );
  }

  final String username;
  final String password;
  final String key;
  final DateTime loginTimestamp;

  @override
  String toString() => '$runtimeType($username)';
}

@immutable
class User {
  const User({
    @required this.username,
    this.displayName,
    this.currentLocation,
    this.roomNumber,
    this.realName,
    this.homeLocation,
  }) : assert(username != null),
       assert(username != '');

  final String username;
  final String displayName;

  final String currentLocation;
  final String roomNumber;
  final String realName;
  final String homeLocation;

  // final bool isvCardPublic;

  // final int numberOfTweets;
  // final int numberOfMentions;

  // final bool isEmailPublic;
  // final bool isAdmin;
  // final String status;
  // final String lastLogin;
  // final bool emptyPassword;
  // final bool unnoticedAlerts;

  bool sameAs(User other) => username == other.username;

  @override
  String toString() {
    if (displayName == username || displayName == '')
      return '@$username';
    return '$displayName (@$username)';
  }

  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != runtimeType)
      return false;
    final User typedOther = other;
    return username == typedOther.username
        || displayName == typedOther.displayName;
  }

  @override
  int get hashCode => hashValues(username, displayName);
}

class AuthenticatedUser extends User {
  const AuthenticatedUser({
    String username,
    String displayName,
    String currentLocation,
    String roomNumber,
    String realName,
    String homeLocation,
    this.email,
    this.credentials,
  }) : super(
    username: username,
    displayName: displayName,
    currentLocation: currentLocation,
    roomNumber: roomNumber,
    realName: realName,
    homeLocation: homeLocation,
  );

  final String email;
  final Credentials credentials;

  static bool isValidUsername(String username) {
    // https://github.com/seamonkeysocial/twitarr/blob/master/app/models/user.rb#L10
    assert(username != null);
    return username.contains(new RegExp(r'^[\w&-]{3,}$'));
  }

  static bool isValidPassword(String password) {
    // https://github.com/hendusoone/twitarr/blob/master/app/controllers/api/v2/user_controller.rb#L26
    assert(password != null);
    return password.length >= 5;
  }

  static bool isValidDisplayName(String displayName) {
    // https://github.com/seamonkeysocial/twitarr/blob/master/app/models/user.rb#L64
    // https://github.com/seamonkeysocial/twitarr/blob/master/app/models/user.rb#L11
    return displayName == null || displayName.contains(new RegExp(r'^[\w\. &-]{3,40}$'));
  }

  static bool isValidEmail(String email, { bool skipServerCheck: false }) {
    assert(email != null);
    // https://html.spec.whatwg.org/#valid-e-mail-address
    if (!email.contains(new RegExp(r"^[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$")))
      return false;
    // https://github.com/seamonkeysocial/twitarr/blob/master/app/models/user.rb#L10
    return skipServerCheck || email.contains(new RegExp(r'\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}\b', caseSensitive: false));
  }

  static bool isValidSecurityQuestion(String question) {
    assert(question != null);
    // https://github.com/seamonkeysocial/twitarr/blob/master/app/models/user.rb#L51
    return question.isNotEmpty;
  }

  static bool isValidSecurityAnswer(String answer) {
    assert(answer != null);
    // https://github.com/seamonkeysocial/twitarr/blob/master/app/models/user.rb#L51
    return answer.isNotEmpty;
  }

  static bool isValidRoomNumber(String roomNumber) {
    assert(roomNumber != null);
    return roomNumber.contains(new RegExp(r'^[0-9]+$'));
  }
}
