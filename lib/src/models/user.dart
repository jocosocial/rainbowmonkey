import 'dart:ui' show hashValues;

import 'package:flutter/foundation.dart';

enum Role { admin, tho, moderator, user, muted, banned, none }

@immutable
class Credentials {
  const Credentials({
    this.username,
    this.password,
    this.key,
    this.loginTimestamp,
    this.asMod = false,
  }) : assert(asMod != null);

  Credentials copyWith({
    String username,
    String password,
    String key,
    DateTime loginTimestamp,
    bool asMod,
  }) {
    return Credentials(
      username: username ?? this.username,
      password: password ?? this.password,
      key: key ?? this.key,
      loginTimestamp: loginTimestamp ?? this.loginTimestamp,
      asMod: asMod ?? this.asMod,
    );
  }

  final String username;
  final String password;
  final String key;
  final DateTime loginTimestamp;
  final bool asMod;

  String get effectiveUsername => asMod ? 'moderator' : username;

  @override
  String toString() => '$runtimeType(${ asMod ? "moderator; login " : ""}$username)';
}

@immutable
class User implements Comparable<User> {
  const User({
    @required this.username,
    this.displayName,
    this.realName,
    this.pronouns,
    this.roomNumber,
    this.homeLocation,
    this.email,
    @required this.role,
  }) : assert(username != null),
       assert(username != ''),
       assert(role != null);

  const User.none(
  ) : username = null,
      displayName = null,
      realName = null,
      pronouns = null,
      roomNumber = null,
      homeLocation = null,
      email = null,
      role = Role.none;

  const User.moderator(
  ) : username = 'moderator',
      displayName = null,
      realName = null,
      pronouns = null,
      roomNumber = null,
      homeLocation = null,
      email = null,
      role = Role.moderator;

  final String username;
  final String displayName;
  final String realName;
  final String pronouns;
  final String roomNumber;
  final String homeLocation;
  final String email;
  final Role role;

  bool sameAs(User other) => other != null && username == other.username;

  @override
  int compareTo(User other) {
    return username.compareTo(other.username);
  }

  bool get isModerator => username == 'moderator';

  User get effectiveUser => this; // ignore: avoid_returning_this

  bool get canPost {
    assert(role != null);
    switch (role) {
      case Role.admin:
      case Role.tho:
      case Role.moderator:
      case Role.user:
        return true;
      case Role.muted:
      case Role.banned:
      case Role.none:
        return false;
    }
    return null;
  }

  bool get canPostWhenLocked {
    assert(role != null);
    switch (role) {
      case Role.admin:
      case Role.tho:
      case Role.moderator:
        return true;
      case Role.user:
      case Role.muted:
      case Role.banned:
      case Role.none:
        return false;
    }
    return null;
  }

  bool get canAlwaysEdit {
    assert(role != null);
    switch (role) {
      case Role.admin:
      case Role.tho:
        return true;
      case Role.moderator:
      case Role.user:
      case Role.muted:
      case Role.banned:
      case Role.none:
        return false;
    }
    return null;
  }

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
        && realName == typedOther.realName
        && pronouns == typedOther.pronouns
        && roomNumber == typedOther.roomNumber
        && homeLocation == typedOther.homeLocation
        && email == typedOther.email
        && role == typedOther.role;
  }

  @override
  int get hashCode => hashValues(
    username,
    displayName,
    realName,
    pronouns,
    roomNumber,
    homeLocation,
    email,
    role,
  );
}

class AuthenticatedUser extends User {
  const AuthenticatedUser({
    String username,
    String displayName,
    String realName,
    String pronouns,
    String roomNumber,
    String homeLocation,
    String email,
    @required Role role,
    this.credentials,
  }) : super(
    username: username,
    displayName: displayName,
    realName: realName,
    pronouns: pronouns,
    roomNumber: roomNumber,
    homeLocation: homeLocation,
    email: email,
    role: role,
  );

  final Credentials credentials;

  @override
  User get effectiveUser => credentials.asMod ? const User.moderator() : this;

  static bool isValidUsername(String username) {
    // https://github.com/seamonkeysocial/twitarr/blob/master/app/models/user.rb#L10
    assert(username != null);
    return username.contains(RegExp(r'^[\w]{3,40}$'));
  }

  static bool isValidPassword(String password, { bool allowShort = false }) {
    // https://github.com/hendusoone/twitarr/blob/master/app/controllers/api/v2/user_controller.rb#L71
    assert(password != null);
    return password.length >= (allowShort ? 1 : 6);
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
    return email.isEmpty || email.contains(RegExp(r"^[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$"));
  }

  static bool isValidRoomNumber(String roomNumber) {
    assert(roomNumber != null);
    return roomNumber.isEmpty || roomNumber.contains(RegExp(r'^[0-9]{4,5}$'));
  }

  AuthenticatedUser copyWith({
    String username,
    String displayName,
    String realName,
    String pronouns,
    String roomNumber,
    String homeLocation,
    String email,
    Role role,
    Credentials credentials,
  }) {
    return AuthenticatedUser(
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      realName: realName ?? this.realName,
      pronouns: pronouns ?? this.pronouns,
      roomNumber: roomNumber ?? this.roomNumber,
      homeLocation: homeLocation ?? this.homeLocation,
      email: email ?? this.email,
      role: role ?? this.role,
      credentials: credentials ?? this.credentials,
    );
  }
}
