import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../json.dart';
import '../logic/photo_manager.dart';
import '../models/calendar.dart';
import '../models/server_text.dart';
import '../models/user.dart';
import '../progress.dart';
import 'form_data.dart';
import 'twitarr.dart';

const String _kShipTwitarrUrl = 'http://joco.hollandamerica.com/';
const String _kDevTwitarrUrl = 'http://twitarrdev.wookieefive.net:3000/';

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
      final Json errors = data.errors as Json;
      if (errors.valueType != Null) {
        if (errors.isMap) {
          throw FieldErrors(errors.toMap().map<String, List<String>>(
            (String field, dynamic value) => MapEntry<String, List<String>>(field, (value as List<dynamic>).cast<String>())
          ));
        }
        throw ServerError(errors.toList().cast<String>().where((String value) => value != null && value.isNotEmpty).toList());
      }
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
    );
  }

  @override
  Progress<Calendar> getCalendar({
    Credentials credentials,
  }) {
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
          _requestUtf8('GET', 'api/v2/event?${body.toUrlEncoded()}'),
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
          _requestUtf8('GET', 'api/v2/announcements?${body.toUrlEncoded()}'),
        ),
      );
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

  @override
  Progress<ServerText> fetchServerText(String filename) {
    final FormData body = FormData()
      ..add('app', 'plain');
    return Progress<ServerText>((ProgressController<ServerText> completer) async {
      return await compute<String, ServerText>(
        _parseServerText,
        await completer.chain<String>(
          _requestUtf8('GET', 'api/v2/text/${Uri.encodeComponent(filename)}?${body.toUrlEncoded()}'),
        ),
      );
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
    });
  }

  @override
  Progress<void> uploadAvatar({
    @required Credentials credentials,
    @required Uint8List bytes,
  }) {
    assert(credentials != null);
    final FormData body = FormData()
      ..add('key', credentials.key)
      ..addFile('file', 'avatar.png', bytes, ContentType('image', 'jpeg'));
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
  Progress<Uint8List> fetchImage(String photoId) {
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
      ..addFile('file', 'image.png', bytes, ContentType('image', 'jpeg'));
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
    if (searchTerm.isEmpty)
      return Progress<List<User>>.completed(const <User>[]);
    searchTerm = searchTerm.runes.map<String>((int rune) => '[${String.fromCharCode(rune)}]').join('');
    return Progress<List<User>>((ProgressController<List<User>> completer) async {
      final List<User> result = await compute<String, List<User>>(
        _parseUserList,
        await completer.chain<String>(
          _requestUtf8('GET', 'api/v2/user/ac/${Uri.encodeComponent(searchTerm)}'),
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
      );
    }).toList();
  }

  @override
  Progress<SeamailSummary> getSeamailThreads({
    @required Credentials credentials,
    int freshnessToken,
  }) {
    assert(credentials.key != null);
    final FormData body = FormData()
      ..add('key', credentials.key)
      ..add('exclude_read_messages', 'true')
      ..add('app', 'plain');
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
    assert(credentials.key != null);
    final FormData body = FormData()
      ..add('key', credentials.key)
      ..add('unread', 'true');
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
    assert(credentials.key != null);
    assert(threadId != null);
    assert(markRead != null);
    final FormData body = FormData()
      ..add('key', credentials.key)
      ..add('app', 'plain');
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
      final String jsonBody = json.encode(<String, dynamic>{
        'users': users
          .where((User user) => user.username != credentials.username)
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
    assert(credentials.key != null);
    assert(threadId != null);
    assert(threadId.isNotEmpty);
    assert(text != null);
    assert(text.isNotEmpty);
    return Progress<SeamailMessageSummary>((ProgressController<SeamailMessageSummary> completer) async {
      final FormData body = FormData()
        ..add('key', credentials.key)
        ..add('app', 'plain');
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
      throw ServerError((data.errors as Json).toList().cast<String>());
    return _parseSeamailThread(data.seamail);
  }

  static SeamailMessageSummary _parseSeamailMessageCreationResult(String rawData) {
    final dynamic data = Json.parse(rawData);
    if (data.status.toString() == 'error') {
      if ((data as Json).hasKey('errors'))
        throw ServerError((data.errors as Json).toList().cast<String>());
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
    assert(credentials == null || credentials.key != null);
    assert(direction != null);
    assert(limit != null);
    assert(limit > 0);
    return Progress<StreamSliceSummary>((ProgressController<StreamSliceSummary> completer) async {
      final FormData body = FormData()
        ..add('include_deleted', 'true')
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
        steps: 2
      );
      final dynamic data = Json.parse(result);
      _checkStatusIsOk(data);
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
    final Set<StreamMessageSummary> posts = <StreamMessageSummary>{};
    for (dynamic post in (data.stream_posts as Json).asIterable()) {
      posts.add(_parseStreamPost(post as Json));
      if ((post as Json).hasKey('children')) {
        final List<String> parents = <String>[post.id.toString()];
        for (dynamic subpost in (post.children as Json).asIterable()) {
          posts.add(_parseStreamPost(subpost as Json, parents));
          parents.add(subpost.id.toString());
        }
      }
    }
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
      posts: posts.toList(), // we assume server's sort order is good
    );
  }

  static StreamMessageSummary _parseStreamPost(dynamic post, [ List<String> parents ]) {
    if ((post as Json).hasKey('deleted') && (post.deleted as bool)) {
      return StreamMessageSummary.deleted(
        id: post.id.toString(),
        timestamp: _parseDateTime(post.timestamp as Json),
        boundaryToken: (post.timestamp as Json).toInt(),
      );
    }
    return StreamMessageSummary(
      id: post.id.toString(),
      user: _parseUser(post.author as Json),
      text: post.text.toString(),
      timestamp: _parseDateTime(post.timestamp as Json),
      boundaryToken: (post.timestamp as Json).toInt(),
      photoId: (post as Json).hasKey('photo') ? post.photo.id.toString() : null,
      reactions: _parseReactions(post.reactions as Json),
      parents: (post as Json).hasKey('parent_chain') ? _parseParents(post.parent_chain as Json) : parents,
    );
  }

  static Map<String, Set<UserSummary>> _parseReactions(dynamic reactions) {
    // TODO(ianh): parse this
    return <String, Set<UserSummary>>{}; // DO NOT MAKE THIS CONST -- SEE https://github.com/dart-lang/sdk/issues/35778
  }

  static List<String> _parseParents(dynamic parentChain) {
    // TODO(ianh): parse this
    return const <String>[];
  }

  @override
  Progress<Set<ForumSummary>> getForumThreads({
    Credentials credentials,
  }) {
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
          ),
        ),
      );
    });
  }

  @override
  Progress<List<ForumMessageSummary>> getForumMessages({
    Credentials credentials,
    @required String threadId,
  }) {
    assert(credentials == null || credentials.key != null);
    assert(threadId != null);
    return Progress<List<ForumMessageSummary>>((ProgressController<List<ForumMessageSummary>> completer) async {
      final FormData body = FormData()
        ..add('app', 'plain');
      if (credentials != null)
        body.add('key', credentials.key);
      return await compute<String, List<ForumMessageSummary>>(
        _parseForumThread,
        await completer.chain<String>(
          _requestUtf8(
            'GET',
            'api/v2/forums/${Uri.encodeComponent(threadId)}?${body.toUrlEncoded()}',
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
      return _parseForumCreationResult(rawData);
    });
  }

  @override
  Progress<void> postForumMessage({
    Credentials credentials,
    @required String threadId,
    @required String text,
    @required List<Uint8List> photos,
  }) {
    assert(credentials.key != null);
    assert(threadId != null);
    assert(text != null);
    assert(photos == null || photos.isNotEmpty);
    return Progress<ForumSummary>((ProgressController<ForumSummary> completer) async {
      final FormData body = FormData()
        ..add('app', 'plain');
      if (credentials != null)
        body.add('key', credentials.key);
      final Map<String, dynamic> details = <String, dynamic>{
        'text': text,
      };
      if (photos != null) {
        final List<String> photoIds = <String>[];
        for (Uint8List photo in photos)
          photoIds.add(await completer.chain<String>(uploadImage(credentials: credentials, bytes: photo), steps: photos.length + 1));
        details['photos'] = photoIds;
      }
      final String jsonBody = json.encode(details);
      await completer.chain<String>(
        _requestUtf8(
          'POST',
          'api/v2/forums/${Uri.encodeComponent(threadId)}?${body.toUrlEncoded()}',
          body: utf8.encode(jsonBody),
          contentType: ContentType('application', 'json', charset: 'utf-8'),
          expectedStatusCodes: <int>[200],
        ),
        steps: (photos != null ? photos.length : 0) + 1,
      );
      // We ignore the return value. It's the forum post, but what are you going to do with it?
      // You don't know where it belongs in the forum...
    });
  }

  static Set<ForumSummary> _parseForumList(String rawData) {
    final dynamic data = Json.parse(rawData);
    final Set<ForumSummary> result = <ForumSummary>{};
    for (dynamic forum in (data.forum_threads as Json).asIterable())
      result.add(_parseForumBody(forum as Json));
    return result;
  }

  static ForumSummary _parseForumBody(dynamic data) {
    return ForumSummary(
      id: data.id.toString(),
      subject: data.subject.toString(),
      totalCount: (data.posts as Json).toInt(),
      unreadCount: (data as Json).hasKey('new_posts') ? (data.new_posts as Json).toInt() : null,
      lastMessageUser: _parseUser(data.last_post_author as Json),
      lastMessageTimestamp: _parseDateTime(data.timestamp as Json),
    );
  }

  static ForumSummary _parseForumCreationResult(String rawData) {
    final dynamic data = Json.parse(rawData);
    final dynamic forum = data.forum_thread as Json;
    final List<ForumMessageSummary> posts = _parseForumMessageList(forum.posts as Json);
    return ForumSummary(
      id: forum.id.toString(),
      subject: forum.subject.toString(),
      totalCount: (forum.post_count as Json).toInt(),
      unreadCount: (forum as Json).hasKey('new_posts') ? (forum.new_posts as Json).toInt() : null,
      lastMessageUser: posts.single.user,
      lastMessageTimestamp: posts.single.timestamp,
    );
  }

  static List<ForumMessageSummary> _parseForumThread(String rawData) {
    final dynamic data = Json.parse(rawData);
    return _parseForumMessageList(data.forum_thread.posts as Json);
  }

  static List<ForumMessageSummary> _parseForumMessageList(dynamic posts) {
    final List<ForumMessageSummary> result = <ForumMessageSummary>[];
    for (dynamic post in (posts as Json).asIterable()) {
      result.add(ForumMessageSummary(
        id: post.id.toString(),
        user: _parseUser(post.author as Json),
        text: post.text.toString(),
        photoIds: (post as Json).hasKey('photos')
          ? (post.photos as Json).asIterable().map<String>((dynamic photo) => photo.id.toString()).toList()
          : null,
        timestamp: _parseDateTime(post.timestamp as Json),
        read: (post as Json).hasKey('new') ? (post['new'] as Json).toBoolean() : null,
      ));
    }
    return result;
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
        return DateTime.fromMicrosecondsSinceEpoch(epoch);
      if (epoch >= 10000000000)
        return DateTime.fromMillisecondsSinceEpoch(epoch);
     return DateTime.fromMillisecondsSinceEpoch(epoch * 1000);
    }
    if (value.valueType == String)
      return DateTime.parse(value.toString());
    throw FormatException('Could not interpret DateTime from server', '$value');
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
        debugPrint('<<< ${response.statusCode} $result');
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
      debugPrint('>>> $method $url (body length: $length)');
      return true;
    }());
    try {
      if (_random.nextDouble() > debugReliability)
        throw const LocalError('Fake network failure');
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
      await Future<void>.delayed(Duration(milliseconds: debugLatency.round()));
      if (!expectedStatusCodes.contains(response.statusCode))
        throw HttpServerError(response.statusCode, response.reasonPhrase, url);
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
      if ((data as Json).hasKey('errors'))
        throw ServerError((data.errors as Json).toList().cast<String>());
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
