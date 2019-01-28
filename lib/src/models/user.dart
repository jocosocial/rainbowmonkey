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
    return Credentials(
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

  const User.none(
  ) : username = null,
      displayName = null,
      currentLocation = null,
      roomNumber = null,
      realName = null,
      homeLocation = null;

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
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType)
      return false;
    final User typedOther = other as User;
    return username == typedOther.username
        && displayName == typedOther.displayName
        && currentLocation == typedOther.currentLocation
        && roomNumber == typedOther.roomNumber
        && realName == typedOther.realName
        && homeLocation == typedOther.homeLocation;
  }

  @override
  int get hashCode => hashValues(
    username,
    displayName,
    currentLocation,
    roomNumber,
    realName,
    homeLocation,
  );
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
    return username.contains(RegExp(r'^[\w&-]{3,}$'));
  }

  static bool isValidPassword(String password) {
    // https://github.com/hendusoone/twitarr/blob/master/app/controllers/api/v2/user_controller.rb#L71
    assert(password != null);
    return password.length >= 6;
  }

  static bool isValidDisplayName(String displayName) {
    // https://github.com/seamonkeysocial/twitarr/blob/master/app/models/user.rb#L64
    // https://github.com/seamonkeysocial/twitarr/blob/master/app/models/user.rb#L11
    return displayName == null || displayName.contains(RegExp(r'^[\w\. &-]{3,40}$'));
  }

  static bool isValidRegistrationCode(String registrationCode) {
    assert(registrationCode != null);
    // https://github.com/hendusoone/twitarr/blob/master/app/controllers/api/v2/user_controller.rb#L77
    return registrationCode.isNotEmpty;
  }

  static bool isValidEmail(String email) {
    assert(email != null);
    // https://html.spec.whatwg.org/#valid-e-mail-address
    return email.contains(RegExp(r"^[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$"));
  }

  static bool isValidRoomNumber(String roomNumber) {
    assert(roomNumber != null);
    return roomNumber.contains(RegExp(r'^[0-9]+$'));
  }
}
