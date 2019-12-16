import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';

import '../json.dart';
import '../logic/photo_manager.dart';
import '../models/calendar.dart';
import '../models/errors.dart';
import '../models/reactions.dart';
import '../models/server_status.dart';
import '../models/server_text.dart';
import '../models/user.dart';
import '../progress.dart';
import 'form_data.dart';
import 'twitarr.dart';

const String _kShipTwitarrUrl = 'http://joco.hollandamerica.com/';
const String _kDevTwitarrUrl = 'http://twitarrdev.wookieefive.net:3000/';

const bool _debugVerbose = false;

class RestTwitarrConfiguration extends TwitarrConfiguration {
  const RestTwitarrConfiguration({ @required this.baseUrl }) : assert(baseUrl != null);

  final String baseUrl;

  @override
  Twitarr createTwitarr() => RestTwitarr(baseUrl: baseUrl);

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType)
      return false;
    final RestTwitarrConfiguration typedOther = other as RestTwitarrConfiguration;
    return typedOther.baseUrl == baseUrl;
  }

  @override
  int get hashCode => baseUrl.hashCode;

  static void register() {
    TwitarrConfiguration.register(_prefix, _factory);
  }

  static const String _prefix = 'rest';

  static RestTwitarrConfiguration _factory(String settings) {
    return RestTwitarrConfiguration(baseUrl: settings);
  }

  @override
  String get prefix => _prefix;

  @override
  String get settings => baseUrl;
}

class AutoTwitarrConfiguration extends TwitarrConfiguration {
  const AutoTwitarrConfiguration();

  @override
  Twitarr createTwitarr() {
    final DateTime now = DateTime.now();
    if (now.isBefore(DateTime(2019, 3, 7)) || now.isAfter(DateTime(2019, 3, 18)))
      return RestTwitarr(baseUrl: _kDevTwitarrUrl, isAuto: true);
    return RestTwitarr(baseUrl: _kShipTwitarrUrl, isAuto: true);
  }

  @override
  bool operator ==(Object other) {
    return other.runtimeType == runtimeType;
  }

  @override
  int get hashCode => runtimeType.hashCode;

  static void register() {
    TwitarrConfiguration.register(_prefix, _factory);
  }

  static const String _prefix = 'auto';

  static AutoTwitarrConfiguration _factory(String settings) {
    return const AutoTwitarrConfiguration();
  }

  @override
  String get prefix => _prefix;

  @override
  String get settings => '';
}

/// An implementation of [Twitarr] that uses the HTTP protocol
/// implemented by <https://github.com/seamonkeysocial/twitarr>.
class RestTwitarr implements Twitarr {
  RestTwitarr({ @required this.baseUrl, this.isAuto = false }) : assert(baseUrl != null), assert(isAuto != null) {
    _client = HttpClient();
    _parsedBaseUrl = Uri.parse(baseUrl);
  }

  final String baseUrl;

  final bool isAuto;

  @override
  TwitarrConfiguration get configuration => isAuto ? const AutoTwitarrConfiguration() : RestTwitarrConfiguration(baseUrl: baseUrl);

  @override
  String get photoCacheKey => baseUrl;

  @override
  double debugLatency = 0.0;

  @override
  double debugReliability = 1.0;

  HttpClient _client;
  Uri _parsedBaseUrl;

  @override
  Progress<AuthenticatedUser> createAccount({
    @required String username,
    @required String password,
    @required String registrationCode,
    String displayName,
  }) {
    if (_enabled?.registrationEnabled == false)
      return Progress<AuthenticatedUser>.failed(const LocalError('Account creation has been disabled on the server.'));
    assert(username != null);
    assert(password != null);
    assert(registrationCode != null);
    assert(AuthenticatedUser.isValidUsername(username));
    assert(AuthenticatedUser.isValidDisplayName(username));
    assert(displayName == null || AuthenticatedUser.isValidDisplayName(displayName));
    assert(AuthenticatedUser.isValidPassword(password));
    assert(AuthenticatedUser.isValidRegistrationCode(registrationCode));
    final Map<String, dynamic> fields = <String, dynamic>{
      'new_username': username,
      'new_password': password,
      'registration_code': registrationCode,
    };
    if (displayName != null)
      fields['display_name'] = displayName;
    final String body = json.encode(fields);
    return Progress<AuthenticatedUser>((ProgressController<AuthenticatedUser> completer) async {
      final String result = await completer.chain<String>(
        _requestUtf8(
          'POST',
          'api/v2/user/new',
          body: utf8.encode(body),
          contentType: ContentType('application', 'json', charset: 'utf-8'),
        )
      );
      final dynamic data = Json.parse(result);
      _checkStatusIsOk(data);
      final String key = data.key.toString();
      return _createAuthenticatedUser(
        data.user,
        Credentials(
          username: data.user.username.toString(),
          password: password,
          key: key,
        ),
      );
    });
  }

  @override
  Progress<AuthenticatedUser> login({
    @required String username,
    @required String password,
    @required PhotoManager photoManager,
  }) {
    assert(username != null);
    assert(password != null);
    assert(AuthenticatedUser.isValidUsername(username));
    assert(AuthenticatedUser.isValidPassword(password));
    return Progress<AuthenticatedUser>((ProgressController<AuthenticatedUser> completer) async {
      final FormData body = FormData()
        ..add('username', username)
        ..add('password', password);
      final String result = await completer.chain<String>(
        _requestUtf8(
          'GET',
          'api/v2/user/auth?${body.toUrlEncoded()}',
        ),
        steps: 2,
      );
      final dynamic data = Json.parse(result);
      if (data.status == 'error' && data.error == 'Invalid username or password.') {
        throw const InvalidUsernameOrPasswordError();
      }
      _checkStatusIsOk(data);
      final String key = data.key.toString();
      return completer.chain<AuthenticatedUser>(getAuthenticatedUser(
        Credentials(
          username: username,
          password: password,
          key: key,
          loginTimestamp: DateTime.now(),
        ),
        photoManager,
      ));
    });
  }

  @override
  Progress<AuthenticatedUser> resetPassword({
    @required String username,
    @required String registrationCode,
    @required String password,
    @required PhotoManager photoManager,
  }) {
    assert(username != null);
    assert(registrationCode != null);
    assert(password != null);
    assert(AuthenticatedUser.isValidUsername(username));
    assert(AuthenticatedUser.isValidRegistrationCode(registrationCode));
    assert(AuthenticatedUser.isValidPassword(password));
    return Progress<AuthenticatedUser>((ProgressController<AuthenticatedUser> completer) async {
      final String jsonBody = json.encode(<String, dynamic>{
        'username': username,
        'registration_code': registrationCode,
        'password': password,
      });
      final String resetRawData = await completer.chain<String>(
        _requestUtf8(
          'POST',
          'api/v2/user/reset_password',
          body: utf8.encode(jsonBody),
          contentType: ContentType('application', 'json', charset: 'utf-8'),
        ),
        steps: 3,
      );
      final dynamic resetData = Json.parse(resetRawData);
      try {
        _checkStatusIsOk(resetData);
      } on FieldErrors catch (error) {
        if (error.fields['username']?.contains('Username and registration code combination not found.') == true)
          throw const InvalidUserAndRegistrationCodeError();
        rethrow;
      }
      final FormData body = FormData()
        ..add('username', username)
        ..add('password', password);
      final String loginRawData = await completer.chain<String>(
        _requestUtf8(
          'GET',
          'api/v2/user/auth?${body.toUrlEncoded()}',
        ),
        steps: 3,
      );
      final dynamic loginData = Json.parse(loginRawData);
      _checkStatusIsOk(loginData);
      final String key = loginData.key.toString();
      return completer.chain<AuthenticatedUser>(getAuthenticatedUser(
        Credentials(
          username: username,
          password: password,
          key: key,
          loginTimestamp: DateTime.now(),
        ),
        photoManager,
      ));
    });
  }

  @override
  Progress<AuthenticatedUser> changePassword({
    @required Credentials credentials,
    @required String newPassword,
    @required PhotoManager photoManager,
  }) {
    assert(credentials != null);
    assert(newPassword != null);
    assert(AuthenticatedUser.isValidPassword(newPassword));
    return Progress<AuthenticatedUser>((ProgressController<AuthenticatedUser> completer) async {
      final FormData body = FormData()
        ..add('key', credentials.key);
      final String jsonBody = json.encode(<String, dynamic>{
        'current_password': credentials.password,
        'new_password': newPassword,
      });
      final String result = await completer.chain<String>(
        _requestUtf8(
          'POST',
          'api/v2/user/change_password?${body.toUrlEncoded()}',
          body: utf8.encode(jsonBody),
          contentType: ContentType('application', 'json', charset: 'utf-8'),
        ),
        steps: 2,
      );
      final dynamic data = Json.parse(result);
      if (data.status == 'error' && data.error == 'Invalid username or password.') {
        throw const InvalidUsernameOrPasswordError();
      }
      _checkStatusIsOk(data);
      final String key = data.key.toString();
      return completer.chain<AuthenticatedUser>(getAuthenticatedUser(
        Credentials(
          username: credentials.username,
          password: newPassword,
          key: key,
          loginTimestamp: DateTime.now(),
        ),
        photoManager,
      ));
    });
  }

  @override
  Progress<AuthenticatedUser> getAuthenticatedUser(Credentials credentials, PhotoManager photoManager) {
    assert(credentials.key != null);
    return Progress<AuthenticatedUser>((ProgressController<AuthenticatedUser> completer) async {
      final FormData body = FormData()
        ..add('key', credentials.key);
      final String rawResult = await completer.chain<String>(_requestUtf8('GET', 'api/v2/user/profile?${body.toUrlEncoded()}'));
      final dynamic data = Json.parse(rawResult);
      _checkStatusIsOk(data);
      photoManager.heardAboutUserPhoto(
        data.user.username.toString(),
        _parseDateTime(data.user.last_photo_updated as Json),
      );
      return _createAuthenticatedUser(data.user, credentials);
    });
  }

  @override
  Progress<User> getUser(Credentials credentials, String username, PhotoManager photoManager) {
    return Progress<User>((ProgressController<User> completer) async {
      final FormData body = FormData();
      if (credentials != null)
        body.add('key', credentials.key);
      final String rawResult = await completer.chain<String>(_requestUtf8('GET', 'api/v2/user/profile/${Uri.encodeComponent(username)}?${body.toUrlEncoded()}'));
      final dynamic data = Json.parse(rawResult);
      _checkStatusIsOk(data);
      photoManager.heardAboutUserPhoto(
        data.user.username.toString(),
        _parseDateTime(data.user.last_photo_updated as Json),
      );
      return _createUser(data.user);
    });
  }

  AuthenticatedUser _createAuthenticatedUser(dynamic user, Credentials credentials) {
    return AuthenticatedUser(
      username: (user.username as Json).toScalar() as String,
      displayName: (user.display_name as Json).toScalar() as String,
      realName: (user.real_name as Json).toScalar() as String,
      pronouns: (user.pronouns as Json).toScalar() as String,
      roomNumber: (user.room_number as Json).toScalar() as String,
      homeLocation: (user.home_location as Json).toScalar() as String,
      email: (user.email as Json).toScalar() as String,
      role: _parseRole((user.role as Json).toScalar() as String),
      credentials: credentials.copyWith(username: (user.username as Json).toScalar() as String),
    );
  }

  User _createUser(dynamic user) {
    return User(
      username: (user.username as Json).toScalar() as String,
      displayName: (user.display_name as Json).toScalar() as String,
      realName: (user.real_name as Json).toScalar() as String,
      pronouns: (user.pronouns as Json).toScalar() as String,
      roomNumber: (user.room_number as Json).toScalar() as String,
      homeLocation: (user.home_location as Json).toScalar() as String,
      email: (user.email as Json).toScalar() as String,
      role: _parseRole((user.role as Json).toScalar() as String),
    );
  }

  Role _parseRole(String role) {
    switch (role) {
      case 'admin': return Role.admin;
      case 'tho': return Role.tho;
      case 'moderator': return Role.moderator;
      case 'user': return Role.user;
      case 'muted': return Role.muted;
      case 'banned': return Role.banned;
      default: return Role.none;
    }
  }

  @override
  Progress<Calendar> getCalendar({
    Credentials credentials,
  }) {
    if (_enabled?.calendarEnabled == false)
      return Progress<Calendar>.completed(Calendar(events: const <Event>[]));
    final FormData body = FormData()
      ..add('app', 'plain');
    if (credentials != null) {
      assert(credentials.key != null);
      body.add('key', credentials.key);
    }
    return Progress<Calendar>((ProgressController<Calendar> completer) async {
      return await compute<String, Calendar>(
        _parseCalendar,
        await completer.chain<String>(
          _requestUtf8(
            'GET',
            'api/v2/event?${body.toUrlEncoded()}',
            expectedStatusCodes: <int>[200],
          ),
        ),
      );
    });
  }

  @override
  Progress<void> setEventFavorite({
    @required Credentials credentials,
    @required String eventId,
    @required bool favorite,
  }) {
    if (_enabled?.calendarEnabled == false)
      return Progress<void>.failed(const LocalError('The calendar has been disabled on the server.'));
    final FormData body = FormData()
      ..add('key', credentials.key)
      ..add('app', 'plain');
    return Progress<void>((ProgressController<void> completer) async {
      await completer.chain<String>(
        _requestUtf8(
          favorite ? 'POST' : 'DELETE',
          'api/v2/event/${Uri.encodeComponent(eventId)}/favorite?${body.toUrlEncoded()}',
        ),
      );
    });
  }

  static Calendar _parseCalendar(String rawData) {
    final dynamic data = Json.parse(rawData);
    _checkStatusIsOk(data);
    return Calendar(events: (data.events as Json).asIterable().map<Event>((dynamic value) {
      return Event(
        id: value.id.toString(),
        title: value.title.toString(),
        official: (value.official as Json).toBoolean(),
        following: (value.following as Json).toBoolean(),
        description: (value.description as Json).valueType == String ? value.description.toString() : null,
        location: value.location.toString(),
        startTime: _parseDateTime(value.start_time as Json),
        endTime: _parseDateTime(value.end_time as Json),
      );
    }).toList());
  }

  @override
  Progress<List<AnnouncementSummary>> getAnnouncements() {
    final FormData body = FormData()
      ..add('app', 'plain');
    return Progress<List<AnnouncementSummary>>((ProgressController<List<AnnouncementSummary>> completer) async {
      return await compute<String, List<AnnouncementSummary>>(
        _parseAnnouncements,
        await completer.chain<String>(
          _requestUtf8(
            'GET',
            'api/v2/announcements?${body.toUrlEncoded()}',
            expectedStatusCodes: <int>[200],
          ),
        ),
      );
    });
  }

  @override
  Progress<Map<String, bool>> getSectionStatus() {
    return Progress<Map<String, bool>>((ProgressController<Map<String, bool>> completer) async {
      final String rawData = await completer.chain<String>(_requestUtf8('GET', 'api/v2/admin/sections'));
      if (rawData.isEmpty)
        return const <String, bool>{};
      final dynamic data = Json.parse(rawData);
      _checkStatusIsOk(data);
      final Map<String, bool> result = <String, bool>{};
      for (dynamic section in (data.sections as Json).asIterable())
        result[section.name.toString()] = (section.enabled as Json).toBoolean();
      return result;
    });
  }

  static List<AnnouncementSummary> _parseAnnouncements(String rawData) {
    final dynamic data = Json.parse(rawData);
    _checkStatusIsOk(data);
    return (data.announcements as Json).asIterable().map<AnnouncementSummary>((dynamic value) {
      return AnnouncementSummary(
        id: value.id.toString(),
        user: _parseUser(value.author as Json),
        message: value.text.toString(),
        timestamp: _parseDateTime(value.timestamp as Json),
      );
    }).toList();
  }

  final Map<String, ServerText> _serverTextCache = <String, ServerText>{};

  @override
  Progress<ServerText> fetchServerText(String filename) {
    if (_serverTextCache.containsKey(filename))
      return Progress<ServerText>.completed(_serverTextCache[filename]);
    final FormData body = FormData()
      ..add('app', 'plain');
    return Progress<ServerText>((ProgressController<ServerText> completer) async {
      final ServerText result = await compute<String, ServerText>(
        _parseServerText,
        await completer.chain<String>(
          _requestUtf8(
            'GET',
            'api/v2/text/${Uri.encodeComponent(filename)}?${body.toUrlEncoded()}',
            expectedStatusCodes: <int>[200],
          ),
        ),
      );
      _serverTextCache[filename] = result;
      return result;
    });
  }

  static ServerText _parseServerText(String rawData) {
    final Json data = Json.parse(rawData);
    final List<dynamic> sectionsList = ((data.asIterable().first as dynamic).sections as Json).asIterable().toList();
    return ServerText(sectionsList.map<ServerTextSection>((dynamic section) {
      String header;
      if ((section as Json).hasKey('header'))
        header = section.header.toString();
      List<ServerTextParagraph> paragraphs;
      if ((section as Json).hasKey('paragraphs')) {
        paragraphs = (section.paragraphs as Json).asIterable().expand<ServerTextParagraph>((dynamic paragraph) sync* {
          if ((paragraph as Json).hasKey('text'))
            yield ServerTextParagraph(paragraph.text.toString());
          if ((paragraph as Json).hasKey('list')) {
            yield* (paragraph.list as Json).asIterable().map<ServerTextParagraph>((dynamic item) {
              return ServerTextParagraph(item.toString(), hasBullet: true);
            });
          }
        }).toList();
      }
      return ServerTextSection(header: header, paragraphs: paragraphs);
    }).toList());
  }

  @override
  Progress<Uint8List> fetchProfilePicture(String username) {
    return _requestBytes('GET', 'api/v2/user/photo/${Uri.encodeComponent(username)}');
  }

  @override
  Progress<void> updateProfile({
    @required Credentials credentials,
    String displayName,
    String realName,
    String pronouns,
    String email,
    String homeLocation,
    String roomNumber,
  }) {
    if (_enabled?.userProfileEnabled == false)
      return Progress<void>.failed(const LocalError('User profiles have been disabled on the server.'));
    assert(credentials != null);
    final FormData body = FormData()
      ..add('key', credentials.key);
    if (displayName != null) {
      assert(AuthenticatedUser.isValidDisplayName(displayName));
      body.add('display_name', displayName);
    }
    if (realName != null) {
      body.add('real_name', realName);
    }
    if (pronouns != null) {
      body.add('pronouns', pronouns);
    }
    if (email != null) {
      assert(AuthenticatedUser.isValidEmail(email));
      body.add('email', email);
    }
    if (homeLocation != null) {
      body.add('home_location', homeLocation);
    }
    if (roomNumber != null) {
      body.add('room_number', roomNumber);
    }
    return Progress<AuthenticatedUser>((ProgressController<AuthenticatedUser> completer) async {
      final String result = await completer.chain<String>(_requestUtf8('POST', 'api/v2/user/profile?${body.toUrlEncoded()}'));
      final dynamic data = Json.parse(result);
      _checkStatusIsOk(data);
      return null;
    });
  }

  @override
  Progress<void> uploadAvatar({
    @required Credentials credentials,
    @required Uint8List bytes,
  }) {
    if (_enabled?.userProfileEnabled == false)
      return Progress<void>.failed(const LocalError('User profiles have been disabled on the server.'));
    assert(credentials != null);
    final FormData body = FormData()
      ..add('key', credentials.key)
      ..addImage('file', bytes);
    final MultipartFormData encoded = body.toMultipartEncoded();
    return Progress<void>((ProgressController<void> completer) async {
      final String result = await completer.chain<String>(_requestUtf8(
        'POST', 'api/v2/user/photo',
        bodyParts: encoded.body,
        contentType: encoded.contentType,
      ));
      final dynamic data = Json.parse(result);
      _checkStatusIsOk(data);
    });
  }

  @override
  Progress<void> resetAvatar({
    @required Credentials credentials,
  }) {
    if (_enabled?.userProfileEnabled == false)
      return Progress<void>.failed(const LocalError('User profiles have been disabled on the server.'));
    assert(credentials != null);
    final FormData body = FormData()
      ..add('key', credentials.key);
    return Progress<void>((ProgressController<void> completer) async {
      final String result = await completer.chain<String>(_requestUtf8('DELETE', 'api/v2/user/photo?${body.toUrlEncoded()}'));
      final dynamic data = Json.parse(result);
      _checkStatusIsOk(data);
    });
  }

  @override
  Progress<Uint8List> fetchImage(String photoId, { bool thumbnail = false }) {
    if (thumbnail)
      return _requestBytes('GET', 'api/v2/photo/medium_thumb/${Uri.encodeComponent(photoId)}');
    return _requestBytes('GET', 'api/v2/photo/full/${Uri.encodeComponent(photoId)}');
  }

  @override
  Progress<String> uploadImage({
    @required Credentials credentials,
    @required Uint8List bytes,
  }) {
    assert(credentials != null);
    final FormData body = FormData()
      ..add('key', credentials.key)
      ..addImage('file', bytes);
    final MultipartFormData encoded = body.toMultipartEncoded();
    return Progress<String>((ProgressController<String> completer) async {
      final String result = await completer.chain<String>(_requestUtf8(
        'POST', 'api/v2/photo',
        bodyParts: encoded.body,
        contentType: encoded.contentType,
      ));
      final dynamic data = Json.parse(result);
      _checkStatusIsOk(data);
      return data.photo.id.toString();
    });
  }

  @override
  Progress<void> updatePassword({
    @required Credentials credentials,
    @required String oldPassword,
    @required String newPassword,
  }) {
    assert(credentials != null);
    assert(AuthenticatedUser.isValidPassword(newPassword));
    return null;
  }

  @override
  Progress<List<User>> getUserList(String searchTerm) {
    // Ruby tries to interpret the search term as a path,
    // so "/", ".", and "\" are all problematic.
    searchTerm = searchTerm
      .replaceAll('.', '')
      .replaceAll('/', '')
      .replaceAll('\\', '')
      .replaceAll('\0', ''); // %00 is particularly bad.
    if (searchTerm.trim().isEmpty)
      return Progress<List<User>>.completed(const <User>[]);
    searchTerm = searchTerm.runes.map<String>((int rune) => '[${String.fromCharCode(rune)}]').join('');
    return Progress<List<User>>((ProgressController<List<User>> completer) async {
      final List<User> result = await compute<String, List<User>>(
        _parseUserList,
        await completer.chain<String>(
          _requestUtf8(
            'GET',
            'api/v2/user/ac/${Uri.encodeComponent(searchTerm)}',
            expectedStatusCodes: <int>[200],
          ),
        ),
      );
      return result;
    });
  }

  static List<User> _parseUserList(String rawData) {
    final dynamic data = Json.parse(rawData);
    final Iterable<dynamic> values = (data.users as Json).asIterable();
    return values.map<User>((dynamic value) {
      return User(
        username: value.username.toString(),
        displayName: value.display_name.toString(),
        role: Role.none,
      );
    }).toList();
  }

  @override
  Progress<SeamailSummary> getSeamailThreads({
    @required Credentials credentials,
    int freshnessToken,
  }) {
    if (_enabled?.seamailEnabled == false)
      return Progress<SeamailSummary>.completed(SeamailSummary(threads: <SeamailThreadSummary>{}, freshnessToken: freshnessToken));
    assert(credentials.key != null);
    final FormData body = FormData()
      ..add('key', credentials.key)
      ..add('exclude_read_messages', 'true')
      ..add('app', 'plain');
    if (credentials.asMod)
      body.add('as_mod', 'true');
    if (freshnessToken != null)
      body.add('after', '$freshnessToken');
    final String encodedBody = body.toUrlEncoded();
    return Progress<SeamailSummary>((ProgressController<SeamailSummary> completer) async {
      return await compute<String, SeamailSummary>(
        _parseSeamailSummary,
        await completer.chain<String>(
          _requestUtf8(
            'GET',
            'api/v2/seamail_threads?$encodedBody',
            expectedStatusCodes: <int>[200],
          ),
        ),
      );
    });
  }

  @override
  Progress<SeamailSummary> getUnreadSeamailMessages({
    @required Credentials credentials,
    int freshnessToken,
  }) {
    if (_enabled?.seamailEnabled == false)
      return Progress<SeamailSummary>.completed(SeamailSummary(threads: <SeamailThreadSummary>{}, freshnessToken: freshnessToken));
    assert(credentials.key != null);
    final FormData body = FormData()
      ..add('key', credentials.key)
      ..add('app', 'plain')
      ..add('unread', 'true');
    if (credentials.asMod)
      body.add('as_mod', 'true');
    if (freshnessToken != null)
      body.add('after', '$freshnessToken');
    final String encodedBody = body.toUrlEncoded();
    return Progress<SeamailSummary>((ProgressController<SeamailSummary> completer) async {
      return await compute<String, SeamailSummary>(
        _parseSeamailSummary,
        await completer.chain<String>(
          _requestUtf8(
            'GET',
            'api/v2/seamail_threads?$encodedBody',
            expectedStatusCodes: <int>[200],
          ),
        ),
      );
    });
  }

  @override
  Progress<SeamailThreadSummary> getSeamailMessages({
    @required Credentials credentials,
    @required String threadId,
    bool markRead = true,
  }) {
    if (_enabled?.seamailEnabled == false)
      return Progress<SeamailThreadSummary>.failed(const LocalError('Seamail has been disabled on the server.'));
    assert(credentials.key != null);
    assert(threadId != null);
    assert(markRead != null);
    final FormData body = FormData()
      ..add('key', credentials.key)
      ..add('app', 'plain');
    if (credentials.asMod)
      body.add('as_mod', 'true');
    if (!markRead)
      body.add('skip_mark_read', 'true');
    final String encodedBody = body.toUrlEncoded();
    return Progress<SeamailThreadSummary>((ProgressController<SeamailThreadSummary> completer) async {
      return await compute<String, SeamailThreadSummary>(
        _parseSeamailThreadWrapper,
        await completer.chain<String>(
          _requestUtf8(
            'GET',
            'api/v2/seamail/${Uri.encodeComponent(threadId)}?$encodedBody',
            expectedStatusCodes: <int>[200],
          ),
        ),
      );
    });
  }

  @override
  Progress<SeamailThreadSummary> createSeamailThread({
    @required Credentials credentials,
    @required Set<User> users,
    @required String subject,
    @required String text,
  }) {
    if (_enabled?.seamailEnabled == false)
      return Progress<SeamailThreadSummary>.failed(const LocalError('Seamail has been disabled on the server.'));
    assert(credentials.key != null);
    assert(users != null);
    assert(users.isNotEmpty);
    assert(subject != null);
    assert(subject.isNotEmpty);
    assert(text != null);
    assert(text.isNotEmpty);
    return Progress<SeamailThreadSummary>((ProgressController<SeamailThreadSummary> completer) async {
      final FormData body = FormData()
        ..add('key', credentials.key)
        ..add('app', 'plain');
      if (credentials.asMod)
        body.add('as_mod', 'true');
      final String jsonBody = json.encode(<String, dynamic>{
        'users': users
          .map<String>((User user) => user.username)
          .toList(),
        'subject': subject,
        'text': text,
      });
      return await compute<String, SeamailThreadSummary>(
        _parseSeamailThreadCreationResult,
        await completer.chain<String>(
          _requestUtf8(
            'POST',
            'api/v2/seamail?${body.toUrlEncoded()}',
            body: utf8.encode(jsonBody),
            contentType: ContentType('application', 'json', charset: 'utf-8'),
            expectedStatusCodes: <int>[200],
          ),
        ),
      );
    });
  }

  @override
  Progress<SeamailMessageSummary> postSeamailMessage({
    @required Credentials credentials,
    @required String threadId,
    @required String text,
  }) {
    if (_enabled?.seamailEnabled == false)
      return Progress<SeamailMessageSummary>.failed(const LocalError('Seamail has been disabled on the server.'));
    assert(credentials.key != null);
    assert(threadId != null);
    assert(threadId.isNotEmpty);
    assert(text != null);
    assert(text.isNotEmpty);
    return Progress<SeamailMessageSummary>((ProgressController<SeamailMessageSummary> completer) async {
      final FormData body = FormData()
        ..add('key', credentials.key)
        ..add('app', 'plain');
      if (credentials.asMod)
        body.add('as_mod', 'true');
      final String jsonBody = json.encode(<String, dynamic>{
        'text': text,
      });
      return await compute<String, SeamailMessageSummary>(
        _parseSeamailMessageCreationResult,
        await completer.chain<String>(
          _requestUtf8(
            'POST',
            'api/v2/seamail/${Uri.encodeComponent(threadId)}?${body.toUrlEncoded()}',
            body: utf8.encode(jsonBody),
            contentType: ContentType('application', 'json', charset: 'utf-8'),
            expectedStatusCodes: <int>[200],
          ),
        ),
      );
    });
  }

  static SeamailSummary _parseSeamailSummary(String rawData) {
    final dynamic data = Json.parse(rawData);
    final Set<SeamailThreadSummary> threads = <SeamailThreadSummary>{};
    for (Json thread in (data.seamail_threads as Json).asIterable()) {
      threads.add(_parseSeamailThread(thread));
    }
    return SeamailSummary(
      threads: threads,
      freshnessToken: (data.last_checked as Json).toInt(),
    );
  }

  static SeamailThreadSummary _parseSeamailThreadWrapper(String rawData) {
    final dynamic data = Json.parse(rawData);
    if (data.status.toString() == 'error')
      throw ServerError(<String>[data.error.toString()]);
    return _parseSeamailThread(data.seamail);
  }

  static SeamailThreadSummary _parseSeamailThreadCreationResult(String rawData) {
    final dynamic data = Json.parse(rawData);
    if (data.status.toString() == 'error')
      throw ServerError((data.errors as Json).toList().cast<String>().toList());
    return _parseSeamailThread(data.seamail);
  }

  static SeamailMessageSummary _parseSeamailMessageCreationResult(String rawData) {
    final dynamic data = Json.parse(rawData);
    if (data.status.toString() == 'error') {
      if ((data as Json).hasKey('errors'))
        throw ServerError((data.errors as Json).toList().cast<String>().toList());
      throw ServerError(<String>[data.error.toString()]);
    }
    return _parseSeamailMessage(data.seamail_message);
  }

  static SeamailThreadSummary _parseSeamailThread(dynamic thread) {
    final bool countIsUnread = (thread.count_is_unread as Json).toBoolean() == true;
    return SeamailThreadSummary(
      id: thread.id.toString(),
      subject: thread.subject.toString(),
      users: Set<UserSummary>.from(
        (thread.users as Json)
          .asIterable()
          .map<UserSummary>(_parseUser)
      ),
      messages: _asListIfPresent<SeamailMessageSummary>(thread.messages as Json, _parseSeamailMessage),
      lastMessageTimestamp: _parseDateTime(thread.timestamp as Json),
      unreadMessages: countIsUnread ? (thread.message_count as Json).toInt() : null,
      totalMessages: countIsUnread ? null : (thread.message_count as Json).toInt(),
      unread: (thread.is_unread as Json).toBoolean(),
    );
  }

  static List<T> _asListIfPresent<T>(Json data, T Function(dynamic data) parser) {
    if (!data.isList)
      return null;
    return data.asIterable().map<T>((Json data) => parser(data)).toList();
  }

  static SeamailMessageSummary _parseSeamailMessage(dynamic message) {
    return SeamailMessageSummary(
      id: message.id.toString(),
      user: _parseUser(message.author as Json),
      text: message.text.toString(),
      timestamp: _parseDateTime(message.timestamp as Json),
      readReceipts: Set<UserSummary>.from(
        (message.read_users as Json)
          .asIterable()
          .map<UserSummary>(_parseUser)
      ),
    );
  }

  @override
  Progress<StreamSliceSummary> getStream({
    Credentials credentials,
    @required StreamDirection direction,
    int boundaryToken,
    int limit = 100,
  }) {
    if (_enabled?.streamEnabled == false)
      return Progress<StreamSliceSummary>.completed(StreamSliceSummary(direction: direction, posts: const <StreamMessageSummary>[], boundaryToken: boundaryToken));
    assert(credentials == null || credentials.key != null);
    assert(direction != null);
    assert(limit != null);
    assert(limit > 0);
    return Progress<StreamSliceSummary>((ProgressController<StreamSliceSummary> completer) async {
      final FormData body = FormData()
        ..add('limit', '$limit')
        ..add('app', 'plain');
      if (credentials != null)
        body.add('key', credentials.key);
      if (boundaryToken != null)
        body.add('start', '$boundaryToken');
      ComputeCallback<String, StreamSliceSummary> parser;
      switch (direction) {
        case StreamDirection.forwards:
          body.add('newer_posts', 'true');
          parser = _parseStreamForwards;
          break;
        case StreamDirection.backwards:
          parser = _parseStreamBackwards;
          break;
      }
      return await compute<String, StreamSliceSummary>(
        parser,
        await completer.chain<String>(
          _requestUtf8(
            'GET',
            'api/v2/stream?${body.toUrlEncoded()}',
            expectedStatusCodes: <int>[200],
          ),
        ),
      );
    });
  }

  @override
  Progress<StreamMessageSummary> getTweet({
    Credentials credentials,
    String threadId,
  }) {
    if (_enabled?.streamEnabled == false)
      return Progress<StreamMessageSummary>.failed(const LocalError('The Twitarr stream has been disabled on the server.'));
    assert(credentials == null || credentials.key != null);
    return Progress<StreamMessageSummary>((ProgressController<StreamMessageSummary> completer) async {
      final FormData body = FormData()
        ..add('limit', '2147483647')
        ..add('app', 'plain');
      if (credentials != null)
        body.add('key', credentials.key);
      return await compute<String, StreamMessageSummary>(
        _parseStreamPostRoot,
        await completer.chain<String>(
          _requestUtf8(
            'GET',
            'api/v2/thread/${Uri.encodeComponent(threadId)}?${body.toUrlEncoded()}',
            expectedStatusCodes: <int>[200], // TODO(ianh): handle 404 cleanly (can happen if tweet was deleted by someone else)
          ),
        ),
      );
    });
  }

  @override
  Progress<void> postTweet({
    @required Credentials credentials,
    @required String text,
    String parentId,
    Uint8List photo,
  }) {
    if (_enabled?.streamEnabled == false)
      return Progress<StreamSliceSummary>.failed(const LocalError('The Twitarr stream has been disabled on the server.'));
    assert(credentials.key != null);
    assert(text != null);
    assert(text.isNotEmpty);
    return Progress<void>((ProgressController<void> completer) async {
      final FormData body = FormData()
        ..add('key', credentials.key)
        ..add('app', 'plain');
      final Map<String, dynamic> details = <String, dynamic>{
        'text': text,
      };
      if (credentials.asMod)
        details['as_mod'] = true;
      if (photo != null)
        details['photo'] = await completer.chain<String>(uploadImage(credentials: credentials, bytes: photo), steps: 2);
      if (parentId != null)
        details['parent'] = parentId;
      final String jsonBody = json.encode(details);
      final String result = await completer.chain<String>(
        _requestUtf8(
          'POST',
          'api/v2/stream?${body.toUrlEncoded()}',
          body: utf8.encode(jsonBody),
          contentType: ContentType('application', 'json', charset: 'utf-8'),
        ),
        steps: photo != null ? 2 : 1
      );
      final dynamic data = Json.parse(result);
      _checkStatusIsOk(data);
    });
  }

  @override
  Progress<void> lockTweet({
    Credentials credentials,
    @required String postId,
    @required bool locked,
  }) {
    if (_enabled?.streamEnabled == false)
      return Progress<StreamSliceSummary>.failed(const LocalError('The Twitarr stream has been disabled on the server.'));
    assert(credentials.key != null);
    assert(postId != null);
    assert(locked != null);
    return Progress<void>((ProgressController<void> completer) async {
      final FormData body = FormData()
        ..add('key', credentials.key);
      final String rawData = await completer.chain<String>(
        _requestUtf8(
          'POST',
          'api/v2/tweet/${Uri.encodeComponent(postId)}/locked/$locked?${body.toUrlEncoded()}',
          expectedStatusCodes: <int>[200, 401, 404],
        ),
      );
      if (rawData.isEmpty)
        return;
      final dynamic data = Json.parse(rawData);
      _checkStatusIsOk(data);
    });
  }

  @override
  Progress<void> editTweet({
    Credentials credentials,
    @required String postId,
    @required String text,
    @required List<String> keptPhotos,
    @required List<Uint8List> newPhotos,
  }) {
    if (_enabled?.streamEnabled == false)
      return Progress<StreamSliceSummary>.failed(const LocalError('The Twitarr stream has been disabled on the server.'));
    assert(credentials.key != null);
    assert(postId != null);
    assert(text != null);
    assert((keptPhotos != null ? keptPhotos.length : 0) + (newPhotos != null ? newPhotos.length : 0) <= 1);
    return Progress<void>((ProgressController<void> completer) async {
      final FormData body = FormData()
        ..add('app', 'plain');
      if (credentials != null)
        body.add('key', credentials.key);
      final Map<String, dynamic> details = <String, dynamic>{
        'text': text,
      };
      if (credentials.asMod)
        details['as_mod'] = true;
      final List<String> photoIds = (keptPhotos ?? const <String>[]).toList();
      if (newPhotos != null) {
        for (Uint8List photo in newPhotos)
          photoIds.add(await completer.chain<String>(uploadImage(credentials: credentials, bytes: photo), steps: newPhotos.length + 1));
      }
      if (photoIds.isNotEmpty)
        details['photo'] = photoIds.single;
      final String jsonBody = json.encode(details);
      final String rawData = await completer.chain<String>(
        _requestUtf8(
          'POST',
          'api/v2/tweet/${Uri.encodeComponent(postId)}?${body.toUrlEncoded()}',
          body: utf8.encode(jsonBody),
          contentType: ContentType('application', 'json', charset: 'utf-8'),
          expectedStatusCodes: <int>[200, 400, 403, 404],
        ),
        steps: (newPhotos != null ? newPhotos.length : 0) + 1,
      );
      final dynamic data = Json.parse(rawData);
      _checkStatusIsOk(data);
    });
  }

  @override
  Progress<void> deleteTweet({
    Credentials credentials,
    @required String postId,
  }) {
    if (_enabled?.streamEnabled == false)
      return Progress<StreamSliceSummary>.failed(const LocalError('The Twitarr stream has been disabled on the server.'));
    assert(credentials.key != null);
    assert(postId != null);
    return Progress<void>((ProgressController<void> completer) async {
      final FormData body = FormData()
        ..add('key', credentials.key);
      final String rawData = await completer.chain<String>(
        _requestUtf8(
          'DELETE',
          'api/v2/tweet/${Uri.encodeComponent(postId)}?${body.toUrlEncoded()}',
          expectedStatusCodes: <int>[204, 403, 404],
        ),
      );
      if (rawData.isEmpty)
        return;
      final dynamic data = Json.parse(rawData);
      _checkStatusIsOk(data);
    });
  }

  @override
  Progress<Map<String, ReactionSummary>> reactTweet({
    @required Credentials credentials,
    @required String postId,
    @required String reaction,
    @required bool selected,
  }) {
    if (_enabled?.streamEnabled == false)
      return Progress<Map<String, ReactionSummary>>.failed(const LocalError('The Twitarr stream has been disabled on the server.'));
    assert(credentials.key != null);
    assert(postId != null);
    assert(reaction != null);
    assert(selected != null);
    return Progress<Map<String, ReactionSummary>>((ProgressController<Map<String, ReactionSummary>> completer) async {
      final FormData body = FormData()
        ..add('key', credentials.key);
      final String rawData = await completer.chain<String>(
        _requestUtf8(
          selected ? 'POST' : 'DELETE',
          'api/v2/tweet/${Uri.encodeComponent(postId)}/react/${Uri.encodeComponent(reaction)}?${body.toUrlEncoded()}',
          expectedStatusCodes: <int>[200, 400, 403, 404],
        ),
      );
      final dynamic data = Json.parse(rawData);
      _checkStatusIsOk(data);
      return _parseReactions(data.reactions as Json);
    });
  }

  @override
  Progress<Map<String, Set<UserSummary>>> getTweetReactions({
    @required String postId,
  }) {
    if (_enabled?.streamEnabled == false)
      return Progress<Map<String, Set<UserSummary>>>.failed(const LocalError('The Twitarr stream has been disabled on the server.'));
    assert(postId != null);
    return Progress<Map<String, Set<UserSummary>>>((ProgressController<Map<String, Set<UserSummary>>> completer) async {
      final String rawData = await completer.chain<String>(
        _requestUtf8(
          'GET',
          'api/v2/tweet/${Uri.encodeComponent(postId)}/react',
          expectedStatusCodes: <int>[200, 404],
        ),
      );
      final dynamic data = Json.parse(rawData);
      _checkStatusIsOk(data);
      return _parseReactionsList(data.reactions as Json);
    });
  }

  static StreamSliceSummary _parseStreamBackwards(String rawData) {
    return _parseStream(rawData, StreamDirection.backwards);
  }

  static StreamSliceSummary _parseStreamForwards(String rawData) {
    return _parseStream(rawData, StreamDirection.forwards);
  }

  static StreamSliceSummary _parseStream(String rawData, StreamDirection direction) {
    final dynamic data = Json.parse(rawData);
    int adjustment;
    switch (direction) {
      case StreamDirection.forwards:
        // with newer_posts=true, server returns posts >= than the given value,
        // but we need to make sure we include the last post from the previous
        // time just to make sure we include any with duplicate timestamps.
        adjustment = -1;
        break;
      case StreamDirection.backwards:
        // with newer_posts=false, server returns posts <= the given value,
        // but we still need to ask for it to include the last tweet from last
        // time just in case there was a duplicate timestamp.
        adjustment = 1;
        break;
    }
    return StreamSliceSummary(
      direction: direction,
      boundaryToken: (data.next_page as Json).toInt() + adjustment,
      posts: (data.stream_posts as Json).asIterable().map<StreamMessageSummary>(_parseStreamPost).toList(),
    );
  }

  static StreamMessageSummary _parseStreamPostRoot(String rawData) {
    final dynamic data = Json.parse(rawData);
    return _parseStreamPost(data.post as Json);
  }

  static StreamMessageSummary _parseStreamPost(dynamic post) {
    return StreamMessageSummary(
      id: post.id.toString(),
      user: _parseUser(post.author as Json),
      text: post.text.toString(),
      timestamp: _parseDateTime(post.timestamp as Json),
      boundaryToken: (post.timestamp as Json).toInt(),
      locked: (post.locked as Json).toBoolean(),
      photo: (post as Json).hasKey('photo') ? _parsePhoto(post.photo) : null,
      reactions: _parseReactions(post.reactions as Json),
      parents: (post as Json).hasKey('parent_chain')
        ? _nullOrNonEmpty<String>((post.parent_chain as Json).asIterable().map<String>((Json value) => value.toString()).toList())
        : null,
      children: (post as Json).hasKey('children')
        ? _nullOrNonEmpty<StreamMessageSummary>((post.children as Json).asIterable().map<StreamMessageSummary>(_parseStreamPost).toList())
        : null,
    );
  }

  static List<T> _nullOrNonEmpty<T>(List<T> list) {
    if (list == null || list.isEmpty)
      return null;
    return list;
  }

  @override
  Progress<Set<ForumSummary>> getForumThreads({
    Credentials credentials,
  }) {
    if (_enabled?.forumsEnabled == false)
      return Progress<Set<ForumSummary>>.completed(const <ForumSummary>{});
    assert(credentials == null || credentials.key != null);
    return Progress<Set<ForumSummary>>((ProgressController<Set<ForumSummary>> completer) async {
      final FormData body = FormData()
        ..add('app', 'plain');
      if (credentials != null)
        body.add('key', credentials.key);
      return await compute<String, Set<ForumSummary>>(
        _parseForumList,
        await completer.chain<String>(
          _requestUtf8(
            'GET',
            'api/v2/forums?${body.toUrlEncoded()}',
            expectedStatusCodes: <int>[200],
          ),
        ),
      );
    });
  }

  @override
  Progress<ForumSummary> getForumThread({
    Credentials credentials,
    @required String threadId,
  }) {
    if (_enabled?.forumsEnabled == false)
      return Progress<ForumSummary>.failed(const LocalError('Forums have been disabled on the server.'));
    assert(credentials == null || credentials.key != null);
    assert(threadId != null);
    return Progress<ForumSummary>((ProgressController<ForumSummary> completer) async {
      final FormData body = FormData()
        ..add('app', 'plain');
      if (credentials != null)
        body.add('key', credentials.key);
      return await compute<String, ForumSummary>(
        _parseForumThread,
        await completer.chain<String>(
          _requestUtf8(
            'GET',
            'api/v2/forums/${Uri.encodeComponent(threadId)}?${body.toUrlEncoded()}',
            expectedStatusCodes: <int>[200],
          ),
        ),
      );
    });
  }

  @override
  Progress<ForumSummary> createForumThread({
    Credentials credentials,
    @required String subject,
    @required String text,
    @required List<Uint8List> photos,
  }) {
    if (_enabled?.forumsEnabled == false)
      return Progress<ForumSummary>.failed(const LocalError('Forums have been disabled on the server.'));
    assert(credentials.key != null);
    assert(subject != null);
    assert(text != null);
    assert(photos == null || photos.isNotEmpty);
    return Progress<ForumSummary>((ProgressController<ForumSummary> completer) async {
      final FormData body = FormData()
        ..add('app', 'plain');
      if (credentials != null)
        body.add('key', credentials.key);
      final Map<String, dynamic> details = <String, dynamic>{
        'subject': subject,
        'text': text,
      };
      if (credentials.asMod)
        details['as_mod'] = true;
      if (photos != null) {
        final List<String> photoIds = <String>[];
        for (Uint8List photo in photos)
          photoIds.add(await completer.chain<String>(uploadImage(credentials: credentials, bytes: photo), steps: photos.length + 1));
        details['photos'] = photoIds;
      }
      final String jsonBody = json.encode(details);
      final String rawData = await completer.chain<String>(
        _requestUtf8(
          'POST',
          'api/v2/forums?${body.toUrlEncoded()}',
          body: utf8.encode(jsonBody),
          contentType: ContentType('application', 'json', charset: 'utf-8'),
        ),
        steps: (photos != null ? photos.length : 0) + 1,
      );
      return _parseForumThread(rawData);
    });
  }

  @override
  Progress<void> stickyForumThread({
    Credentials credentials,
    @required String threadId,
    @required bool sticky,
  }) {
    if (_enabled?.forumsEnabled == false)
      return Progress<void>.failed(const LocalError('Forums have been disabled on the server.'));
    assert(credentials.key != null);
    assert(threadId != null);
    return Progress<void>((ProgressController<void> completer) async {
      final FormData body = FormData()
        ..add('key', credentials.key);
      final String rawData = await completer.chain<String>(
        _requestUtf8(
          'POST',
          'api/v2/forum/${Uri.encodeComponent(threadId)}/sticky/$sticky?${body.toUrlEncoded()}',
          expectedStatusCodes: <int>[200, 401, 404],
        ),
      );
      final dynamic data = Json.parse(rawData);
      _checkStatusIsOk(data);
    });
  }

  @override
  Progress<void> lockForumThread({
    Credentials credentials,
    @required String threadId,
    @required bool locked,
  }) {
    if (_enabled?.forumsEnabled == false)
      return Progress<void>.failed(const LocalError('Forums have been disabled on the server.'));
    assert(credentials.key != null);
    assert(threadId != null);
    return Progress<void>((ProgressController<void> completer) async {
      final FormData body = FormData()
        ..add('key', credentials.key);
      final String rawData = await completer.chain<String>(
        _requestUtf8(
          'POST',
          'api/v2/forum/${Uri.encodeComponent(threadId)}/locked/$locked?${body.toUrlEncoded()}',
          expectedStatusCodes: <int>[200, 401, 404],
        ),
      );
      final dynamic data = Json.parse(rawData);
      _checkStatusIsOk(data);
    });
  }

  @override
  Progress<void> deleteForumThread({
    Credentials credentials,
    @required String threadId,
  }) {
    if (_enabled?.forumsEnabled == false)
      return Progress<void>.failed(const LocalError('Forums have been disabled on the server.'));
    assert(credentials.key != null);
    assert(threadId != null);
    return Progress<void>((ProgressController<void> completer) async {
      final FormData body = FormData()
        ..add('key', credentials.key);
      final String rawData = await completer.chain<String>(
        _requestUtf8(
          'DELETE',
          'api/v2/forums/${Uri.encodeComponent(threadId)}?${body.toUrlEncoded()}',
          expectedStatusCodes: <int>[200, 401, 404],
        ),
      );
      final dynamic data = Json.parse(rawData);
      _checkStatusIsOk(data);
    });
  }

  @override
  Progress<void> postForumMessage({
    Credentials credentials,
    @required String threadId,
    @required String text,
    @required List<Uint8List> photos,
  }) {
    if (_enabled?.forumsEnabled == false)
      return Progress<void>.failed(const LocalError('Forums have been disabled on the server.'));
    assert(credentials.key != null);
    assert(threadId != null);
    assert(text != null);
    assert(photos == null || photos.isNotEmpty);
    return Progress<void>((ProgressController<void> completer) async {
      final FormData body = FormData()
        ..add('app', 'plain');
      if (credentials != null)
        body.add('key', credentials.key);
      final Map<String, dynamic> details = <String, dynamic>{
        'text': text,
      };
      if (credentials.asMod)
        details['as_mod'] = true;
      if (photos != null) {
        final List<String> photoIds = <String>[];
        for (Uint8List photo in photos)
          photoIds.add(await completer.chain<String>(uploadImage(credentials: credentials, bytes: photo), steps: photos.length + 1));
        details['photos'] = photoIds;
      }
      final String jsonBody = json.encode(details);
      final String rawData = await completer.chain<String>(
        _requestUtf8(
          'POST',
          'api/v2/forums/${Uri.encodeComponent(threadId)}?${body.toUrlEncoded()}',
          body: utf8.encode(jsonBody),
          contentType: ContentType('application', 'json', charset: 'utf-8'),
          expectedStatusCodes: <int>[200, 404, 403],
        ),
        steps: (photos != null ? photos.length : 0) + 1,
      );
      final dynamic data = Json.parse(rawData);
      _checkStatusIsOk(data);
    });
  }

  @override
  Progress<void> editForumMessage({
    Credentials credentials,
    @required String threadId,
    @required String messageId,
    @required String text,
    @required List<String> keptPhotos,
    @required List<Uint8List> newPhotos,
  }) {
    if (_enabled?.forumsEnabled == false)
      return Progress<void>.failed(const LocalError('Forums have been disabled on the server.'));
    assert(credentials.key != null);
    assert(threadId != null);
    assert(text != null);
    return Progress<void>((ProgressController<void> completer) async {
      final FormData body = FormData()
        ..add('app', 'plain');
      if (credentials != null)
        body.add('key', credentials.key);
      final Map<String, dynamic> details = <String, dynamic>{
        'text': text,
      };
      if (credentials.asMod)
        details['as_mod'] = true;
      final List<String> photoIds = (keptPhotos ?? const <String>[]).toList();
      if (newPhotos != null) {
        for (Uint8List photo in newPhotos)
          photoIds.add(await completer.chain<String>(uploadImage(credentials: credentials, bytes: photo), steps: newPhotos.length + 1));
      }
      if (photoIds.isNotEmpty)
        details['photos'] = photoIds;
      final String jsonBody = json.encode(details);
      final String rawData = await completer.chain<String>(
        _requestUtf8(
          'POST',
          'api/v2/forums/${Uri.encodeComponent(threadId)}/${Uri.encodeComponent(messageId)}?${body.toUrlEncoded()}',
          body: utf8.encode(jsonBody),
          contentType: ContentType('application', 'json', charset: 'utf-8'),
          expectedStatusCodes: <int>[200, 400, 401, 403, 404],
        ),
        steps: (newPhotos != null ? newPhotos.length : 0) + 1,
      );
      final dynamic data = Json.parse(rawData);
      _checkStatusIsOk(data);
    });
  }

  @override
  Progress<bool> deleteForumMessage({
    Credentials credentials,
    @required String threadId,
    @required String messageId,
  }) {
    if (_enabled?.forumsEnabled == false)
      return Progress<bool>.failed(const LocalError('Forums have been disabled on the server.'));
    assert(credentials.key != null);
    assert(threadId != null);
    assert(messageId != null);
    return Progress<bool>((ProgressController<bool> completer) async {
      final FormData body = FormData()
        ..add('key', credentials.key);
      final String rawData = await completer.chain<String>(
        _requestUtf8(
          'DELETE',
          'api/v2/forums/${Uri.encodeComponent(threadId)}/${Uri.encodeComponent(messageId)}?${body.toUrlEncoded()}',
          expectedStatusCodes: <int>[200, 401, 403, 404],
        ),
      );
      final dynamic data = Json.parse(rawData);
      _checkStatusIsOk(data);
      return (data.thread_deleted as Json).toBoolean();
    });
  }

  @override
  Progress<Map<String, ReactionSummary>> reactForumMessage({
    @required Credentials credentials,
    @required String threadId,
    @required String messageId,
    @required String reaction,
    @required bool selected,
  }) {
    if (_enabled?.forumsEnabled == false)
      return Progress<Map<String, ReactionSummary>>.failed(const LocalError('Forums have been disabled on the server.'));
    assert(credentials.key != null);
    assert(threadId != null);
    assert(messageId != null);
    assert(reaction != null);
    assert(selected != null);
    return Progress<Map<String, ReactionSummary>>((ProgressController<Map<String, ReactionSummary>> completer) async {
      final FormData body = FormData()
        ..add('key', credentials.key);
      final String rawData = await completer.chain<String>(
        _requestUtf8(
          selected ? 'POST' : 'DELETE',
          'api/v2/forums/${Uri.encodeComponent(threadId)}/${Uri.encodeComponent(messageId)}/react/${Uri.encodeComponent(reaction)}?${body.toUrlEncoded()}',
          expectedStatusCodes: <int>[200, 400, 403, 404],
        ),
      );
      final dynamic data = Json.parse(rawData);
      _checkStatusIsOk(data);
      return _parseReactions(data.reactions as Json);
    });
  }

  @override
  Progress<Map<String, Set<UserSummary>>> getForumMessageReactions({
    @required String threadId,
    @required String messageId,
  }) {
    if (_enabled?.forumsEnabled == false)
      return Progress<Map<String, Set<UserSummary>>>.failed(const LocalError('Forums have been disabled on the server.'));
    assert(threadId != null);
    assert(messageId != null);
    return Progress<Map<String, Set<UserSummary>>>((ProgressController<Map<String, Set<UserSummary>>> completer) async {
      final String rawData = await completer.chain<String>(
        _requestUtf8(
          'GET',
          'api/v2/forums/${Uri.encodeComponent(threadId)}/${Uri.encodeComponent(messageId)}/react',
          expectedStatusCodes: <int>[200, 404],
        ),
      );
      final dynamic data = Json.parse(rawData);
      _checkStatusIsOk(data);
      return _parseReactionsList(data.reactions as Json);
    });
  }

  static Set<ForumSummary> _parseForumList(String rawData) {
    final dynamic data = Json.parse(rawData);
    final Set<ForumSummary> result = <ForumSummary>{};
    for (dynamic forum in (data.forum_threads as Json).asIterable())
      result.add(_parseForumBody(forum as Json));
    return result;
  }

  static ForumSummary _parseForumBody(dynamic forum) {
    return ForumSummary(
      id: forum.id.toString(),
      subject: forum.subject.toString(),
      sticky: (forum.sticky as Json).toBoolean(),
      locked: (forum.locked as Json).toBoolean(),
      totalCount: (forum.posts as Json).toInt(),
      unreadCount: (forum as Json).hasKey('new_posts') ? (forum.new_posts as Json).toInt() : null,
      lastMessageUser: _parseUser(forum.last_post_author as Json),
      lastMessageTimestamp: _parseDateTime(forum.timestamp as Json),
    );
  }

  static ForumSummary _parseForumThread(String rawData) {
    final dynamic data = Json.parse(rawData);
    final dynamic forum = data.forum_thread as Json;
    final List<ForumMessageSummary> posts = _parseForumMessageList(forum.posts as Json);
    return ForumSummary(
      id: forum.id.toString(),
      subject: forum.subject.toString(),
      sticky: (forum.sticky as Json).toBoolean(),
      locked: (forum.locked as Json).toBoolean(),
      totalCount: (forum.post_count as Json).toInt(),
      unreadCount: (forum as Json).hasKey('new_posts') ? (forum.new_posts as Json).toInt() : null,
      lastMessageUser: posts.last.user,
      lastMessageTimestamp: posts.last.timestamp,
      messages: posts,
    );
  }

  static List<ForumMessageSummary> _parseForumMessageList(dynamic posts) {
    final List<ForumMessageSummary> result = <ForumMessageSummary>[];
    for (dynamic post in (posts as Json).asIterable()) {
      result.add(ForumMessageSummary(
        id: post.id.toString(),
        user: _parseUser(post.author as Json),
        text: post.text.toString(),
        photos: (post as Json).hasKey('photos')
          ? (post.photos as Json).asIterable().map<Photo>(_parsePhoto).toList()
          : null,
        reactions: _parseReactions(post.reactions as Json),
        timestamp: _parseDateTime(post.timestamp as Json),
        read: (post as Json).hasKey('new') ? (post['new'] as Json).toBoolean() : null,
      ));
    }
    return result;
  }

  static Map<String, ReactionSummary> _parseReactions(Json reactions) {
    return reactions.toMap().map<String, ReactionSummary>((String name, dynamic value) {
      return MapEntry<String, ReactionSummary>(
        name,
        ReactionSummary(
          count: (value['count'] as double).toInt(),
          includesCurrentUser: value['me'] as bool,
        ),
      );
    });
  }

  static Map<String, Set<UserSummary>> _parseReactionsList(Json reactions) {
    final Map<String, Set<UserSummary>> result = <String, Set<UserSummary>>{};
    for (dynamic entry in reactions.asIterable()) {
      final Set<UserSummary> list = result.putIfAbsent(
        entry.reaction.toString(),
        () => <UserSummary>{},
      );
      list.add(_parseUser(entry.user as Json));
    }
    return result;
  }

  @override
  Progress<MentionsSummary> getMentions({
    Credentials credentials,
    bool reset = false,
  }) {
    assert(credentials.key != null);
    final FormData body = FormData()
      ..add('key', credentials.key)
      ..add('app', 'plain');
    if (credentials.asMod)
      body.add('as_mod', 'true');
    if (!reset)
      body.add('no_reset', 'true');
    final String encodedBody = body.toUrlEncoded();
    return Progress<MentionsSummary>((ProgressController<MentionsSummary> completer) async {
      return await compute<String, MentionsSummary>(
        _parseMentionsSummary,
        await completer.chain<String>(
          _requestUtf8(
            'GET',
            'api/v2/alerts?$encodedBody',
            expectedStatusCodes: <int>[200],
          ),
        ),
      );
    });
  }

  @override
  Progress<void> clearMentions({
    Credentials credentials,
    @required int freshnessToken,
  }) {
    assert(freshnessToken != null);
    assert(credentials.key != null);
    final FormData body = FormData()
      ..add('key', credentials.key);
    if (credentials.asMod)
      body.add('as_mod', 'true');
      final Map<String, dynamic> details = <String, dynamic>{
      'last_checked_time': freshnessToken,
    };
    if (credentials.asMod)
      details['as_mod'] = true;
    final String jsonBody = json.encode(details);
    return Progress<void>((ProgressController<void> completer) async {
      final String result = await completer.chain<String>(
        _requestUtf8(
          'POST',
          'api/v2/alerts/last_checked?${body.toUrlEncoded()}',
          body: utf8.encode(jsonBody),
          contentType: ContentType('application', 'json', charset: 'utf-8'),
        ),
      );
      final dynamic data = Json.parse(result);
      _checkStatusIsOk(data);
    });
  }

  static MentionsSummary _parseMentionsSummary(String rawData) {
    final dynamic data = Json.parse(rawData);
    return MentionsSummary(
      streamPosts: (data.tweet_mentions as Json).asIterable().map<StreamMessageSummary>(_parseStreamPost).toList(),
      forums: (data.forum_mentions as Json).asIterable().map<ForumSummary>(_parseForumBody).toList(),
      freshnessToken: (data.query_time as Json).toInt(),
    );
  }

  static UserSummary _parseUser(dynamic user) {
    return UserSummary(
      username: user.username.toString(),
      displayName: user.display_name.toString(),
      photoTimestamp: _parseDateTime(user.last_photo_updated as Json),
    );
  }

  static DateTime _parseDateTime(Json value) {
    if (value.valueType == double) {
      final int epoch = value.toInt();
      if (epoch >= 10000000000000)
        return DateTime.fromMicrosecondsSinceEpoch(epoch, isUtc: true);
      if (epoch >= 10000000000)
        return DateTime.fromMillisecondsSinceEpoch(epoch, isUtc: true);
     return DateTime.fromMillisecondsSinceEpoch(epoch * 1000, isUtc: true);
    }
    if (value.valueType == String)
      return DateTime.parse(value.toString()).toUtc();
    throw FormatException('Could not interpret DateTime from server', '$value');
  }

  static Photo _parsePhoto(dynamic value) {
    final bool hasSizes = (value.sizes as Json).asIterable().isNotEmpty;
    return Photo(
      id: value.id.toString(),
      size: hasSizes ? _parseSize(value.sizes.full.toString()) : Size.zero,
      mediumSize: hasSizes ? _parseSize(value.sizes.medium_thumb.toString()) : Size.zero,
    );
  }

  static Size _parseSize(String resolution) {
    final List<int> values = resolution.split('x').map<int>((String value) => int.parse(value, radix: 10)).toList();
    return Size(values[0].toDouble(), values[1].toDouble());
  }

  static const List<int> _kTwitarrExpectedStatusCodes = <int>[200, 400, 401, 403, 422];

  Progress<String> _requestUtf8(String method, String path, {
    List<int> body,
    List<Uint8List> bodyParts,
    ContentType contentType,
    List<int> expectedStatusCodes = _kTwitarrExpectedStatusCodes,
  }) {
    return Progress<String>((ProgressController<String> completer) async {
      final HttpClientResponse response = await _requestInternal<String>(
        completer,
        method,
        path,
        body,
        bodyParts,
        contentType,
        expectedStatusCodes,
      );
      int count = 0;
      final String result = await response
        .map((List<int> bytes) {
          if (response.contentLength > 0) {
            count += bytes.length;
            completer.advance(count.toDouble(), math.max(count, response.contentLength).toDouble());
          }
          return bytes;
        })
        .transform(utf8.decoder)
        .join();
      assert(() {
        if (_debugVerbose) {
          debugPrint('<<< ${response.statusCode} from $path:');
          for (int index = 0; index < result.length; index += 128)
            debugPrint(' 0x${index.toRadixString(16).padLeft(4, "0")}: ${result.substring(index, math.min(index + 100, result.length))}');
        }
        return true;
      }());
      return result;
    });
  }

  Progress<Uint8List> _requestBytes(String method, String path, {
    List<int> body,
    List<Uint8List> bodyParts,
    ContentType contentType,
    List<int> expectedStatusCodes = _kTwitarrExpectedStatusCodes,
  }) {
    return Progress<Uint8List>((ProgressController<Uint8List> completer) async {
      final HttpClientResponse response = await _requestInternal<Uint8List>(
        completer,
        method,
        path,
        body,
        bodyParts,
        contentType,
        expectedStatusCodes,
      );
      int count = 0;
      final List<List<int>> chunks = <List<int>>[];
      await response.forEach((List<int> chunk) {
        count += chunk.length;
        if (response.contentLength > 0)
          completer.advance(count.toDouble(), response.contentLength.toDouble());
        chunks.add(chunk);
      });
      final Uint8List bytes = Uint8List(count);
      int offset = 0;
      for (List<int> chunk in chunks) {
        bytes.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      }
      return bytes;
    });
  }

  final math.Random _random = math.Random();

  ServerStatus _enabled = const ServerStatus();
  Completer<void> _enabledCompleter = Completer<void>()..complete();

  @override
  void enable(ServerStatus status) {
    assert(status != null);
    _enabled = status;
    if (!_enabledCompleter.isCompleted)
      _enabledCompleter.complete();
  }

  @override
  void disable() {
    _enabled = null;
    if (_enabledCompleter.isCompleted)
      _enabledCompleter = Completer<void>();
  }

  Future<HttpClientResponse> _requestInternal<T>(
    ProgressController<T> completer,
    String method,
    String path,
    List<int> body,
    List<Uint8List> bodyParts,
    ContentType contentType,
    List<int> expectedStatusCodes,
  ) async {
    assert(contentType != null || (body == null && bodyParts == null));
    assert(body == null || bodyParts == null);
    final Uri url = _parsedBaseUrl.resolve(path);
    final int length = body != null ? body.length
                     : bodyParts != null ? bodyParts.fold(0, (int length, Uint8List part) => length + part.length)
                     : null;
    assert(() {
      if (_debugVerbose) {
        debugPrint('>>> $method $url (body length: $length)');
      } else {
        debugPrint('>>> $method ${url.path}');
      }
      return true;
    }());
    try {
      if (_enabled == null) {
        assert(!_enabledCompleter.isCompleted);
        assert(() {
          if (_debugVerbose)
            debugPrint('    (network disabled, waiting...)');
          return true;
        }());
        await _enabledCompleter.future;
      }
      assert(() {
        if (_random.nextDouble() > debugReliability)
          throw const LocalError('Fake network failure');
        return true;
      }());
      final HttpClientRequest request = await _client.openUrl(method, url);
      if (contentType != null)
        request.headers.contentType = contentType;
      if (length != null) {
        // Beware: Puma (used by server) can't handle chunked encoding; see: https://github.com/puma/puma/issues/1492
        request.headers.chunkedTransferEncoding = false;
        request.headers.contentLength = length;
        if (body != null)
          request.add(body);
        if (bodyParts != null)
          bodyParts.forEach(request.add);
      }
      final HttpClientResponse response = await request.close();
      Duration delay;
      assert(() {
        delay = Duration(milliseconds: debugLatency.round());
        return true;
      }());
      if (delay != null)
        await Future<void>.delayed(delay);
      if (!expectedStatusCodes.contains(response.statusCode)) {
        assert(() {
          response.transform(utf8.decoder).join().then((String result) {
            debugPrint('<<< (!!) ${response.statusCode} from $path:');
            for (int index = 0; index < result.length; index += 128)
              debugPrint(' 0x${index.toRadixString(16).padLeft(4, "0")}: ${result.substring(index, math.min(index + 100, result.length)).replaceAll("\n", "␊")}');
          });
          return true;
        }());
        if (response.statusCode == 503)
          throw const FeatureDisabledError();
        throw HttpServerError(response.statusCode, response.reasonPhrase, url);
      }
      if (response.contentLength > 0)
        completer.advance(0.0, response.contentLength.toDouble());
      return response;
    } on SocketException catch (error) {
      if (error.osError.errorCode == 7)
        throw const ServerError(<String>['The DNS server is down or the Twitarr server is non-existent.']);
      if (error.osError.errorCode == 110)
        throw const ServerError(<String>['The network is too slow.']);
      if (error.osError.errorCode == 111 || error.osError.errorCode == 61)
        throw const ServerError(<String>['The server is down.']);
      if (error.osError.errorCode == 113)
        throw const ServerError(<String>['The server cannot be reached.']);
      rethrow;
    }
  }

  static void _checkStatusIsOk(dynamic data) {
    if (data.status.toString() == 'error') {
      final Json errors = data.errors as Json;
      if (errors.valueType != Null) {
        if (errors.isMap) {
          throw FieldErrors(errors.toMap().map<String, List<String>>(
            (String field, dynamic value) => MapEntry<String, List<String>>(field, (value as List<dynamic>).cast<String>().toList())
          ));
        }
        throw ServerError(errors.toList().cast<String>().where((String value) => value != null && value.isNotEmpty).toList());
      }
      throw ServerError(<String>[data.error.toString()]);
    }
    if (data.status != 'ok')
      throw ServerError(<String>['Server said the status was "${data.status}".']);
  }

  @override
  void dispose() {
    _client.close(force: true);
  }
}
