import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../json.dart';
import '../logic/photo_manager.dart';
import '../models/calendar.dart';
import '../models/seamail.dart';
import '../models/user.dart';
import '../progress.dart';
import 'form_data.dart';
import 'twitarr.dart';

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

  @override
  String toString() => 'Twitarr(REST $baseUrl)';
}

/// An implementation of [Twitarr] that uses the HTTP protocol
/// implemented by <https://github.com/seamonkeysocial/twitarr>.
class RestTwitarr implements Twitarr {
  RestTwitarr({ @required this.baseUrl }) : assert(baseUrl != null) {
    _client = HttpClient();
    _parsedBaseUrl = Uri.parse(baseUrl);
  }

  final String baseUrl;

  @override
  TwitarrConfiguration get configuration => RestTwitarrConfiguration(baseUrl: baseUrl);

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
    @required String email,
    @required String securityQuestion,
    @required String securityAnswer,
  }) {
    assert(username != null);
    assert(password != null);
    assert(email != null);
    assert(registrationCode != null);
    assert(securityAnswer != null);
    assert(securityQuestion != null);
    assert(AuthenticatedUser.isValidUsername(username));
    assert(AuthenticatedUser.isValidDisplayName(username));
    assert(AuthenticatedUser.isValidPassword(password));
    assert(AuthenticatedUser.isValidRegistrationCode(registrationCode));
    assert(AuthenticatedUser.isValidEmail(email));
    assert(AuthenticatedUser.isValidSecurityQuestion(securityQuestion));
    assert(AuthenticatedUser.isValidSecurityAnswer(securityAnswer));
    final String body = json.encode(<String, dynamic>{
      'new_username': username,
      'new_password': password,
      'registration_code': registrationCode,
      'email': email,
      'security_question': securityQuestion,
      'security_answer': securityAnswer
    });
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
          expectedStatusCodes: const <int>[200, 401],
        ),
        steps: 2,
      );
      final dynamic data = Json.parse(result);
      if (data['status'] != null &&
          (data.status == 'incorrect username or password' ||
           data.status == 'incorrect password or username')) {
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
  Progress<AuthenticatedUser> logout() {
    return Progress<AuthenticatedUser>((ProgressController<AuthenticatedUser> completer) async {
      await completer.chain<String>(_requestUtf8('POST', 'api/v2/user/logout'), steps: 2);
      return null;
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
        DateTime.fromMicrosecondsSinceEpoch((data.user.last_photo_updated as Json).toInt()),
      );
      return _createAuthenticatedUser(data.user, credentials);
    });
  }

  AuthenticatedUser _createAuthenticatedUser(dynamic user, Credentials credentials) {
    return AuthenticatedUser(
      username: (user.username as Json).toScalar() as String,
      email: (user.email as Json).toScalar() as String,
      displayName: (user.display_name as Json).toScalar() as String,
      currentLocation: (user.current_location as Json).toScalar() as String,
      roomNumber: (user.room_number as Json).toScalar() as String,
      realName: (user.real_name as Json).toScalar() as String,
      homeLocation: (user.home_location as Json).toScalar() as String,
      // isvCardPublic: (user['vcard_public?'] as Json).toBoolean(),
      // isEmailPublic: (user['email_public?'] as Json).toBoolean(),
      // isAdmin: (user.isAdminas Json).toBoolean(),
      // status: (user.status as Json).toScalar() as String,
      // lastLogin: (user.last_login as Json).toScalar() as String, // TODO(ianh): parse to DateTime
      // emptyPassword: (user['empty_password?'] as Json).toBoolean(),
      // unnoticedAlerts: (user.unnoticed_alertsas Json).toBoolean(),
      credentials: credentials.copyWith(username: (user.username as Json).toScalar() as String),
    );
  }

  @override
  Progress<Calendar> getCalendar() {
    return Progress<Calendar>((ProgressController<Calendar> completer) async {
      return await compute<String, Calendar>(
        _parseCalendar,
        await completer.chain<String>(
          _requestUtf8('GET', 'api/v2/event.json'),
        ),
      );
    });
  }

  static Calendar _parseCalendar(String rawEventData) {
    final dynamic data = Json.parse(rawEventData);
    final dynamic values = (data.event.asIterable() as Iterable<dynamic>).single;
    if (values.status != 'ok')
      throw FormatException('status "${values.status}" is not ok');
    if (values.total_count != (values.events.asIterable() as Iterable<dynamic>).length)
      throw const FormatException('total_count invalid');
    return Calendar(events: (values.events.asIterable() as Iterable<dynamic>).map<Event>((dynamic value) {
      return Event(
        id: value.id.toString(),
        title: value.title.toString(),
        official: (value.official as Json).toBoolean(),
        description: value['description']?.toString(),
        location: value.location.toString(),
        startTime: DateTime.parse(value.start_time.toString()),
        endTime: DateTime.parse(value.end_time.toString()),
      );
    }).toList());
  }

  @override
  Future<void> updateSeamailThreads(
    Credentials credentials,
    Seamail seamail,
    PhotoManager photoManager,
    CancelationSignal cancelationSignal,
  ) async {
    assert(credentials.key != null);
    final FormData body = FormData()
      ..add('key', credentials.key);
    final String encodedBody = body.toUrlEncoded();
    final String rawResult = await _requestUtf8('GET', 'api/v2/seamail?$encodedBody').asFuture();
    if (cancelationSignal.canceled)
      return;
    final dynamic data = Json.parse(rawResult);
    seamail.update(DateTime.fromMicrosecondsSinceEpoch((data.last_checked as Json).toInt()), (SeamailUpdater updater) {
      for (dynamic thread in data.seamail_meta.asIterable() as Iterable<dynamic>) {
        final List<User> users = _parseUsersFromSeamailMeta(thread.users as Json, photoManager);
        final String id = thread.id.toString();
        updater.updateThread(id,
          messageCount: _parseMessageCount(thread.messages.toString()),
          subject: thread.subject.toString(),
          timestamp: DateTime.parse(thread.timestamp.toString()),
          unread: (thread.is_unread as Json).toBoolean(),
          users: users,
          messagesCallback: _getMessagesCallback(id, credentials),
          sendCallback: _getSendCallback(id, credentials),
        );
      }
    });
  }

  @override
  Progress<SeamailThread> newSeamail(
    Credentials credentials,
    Seamail seamail,
    PhotoManager photoManager,
    Set<User> users,
    String subject,
    String message,
  ) {
    assert(credentials.key != null);
    return Progress<SeamailThread>((ProgressController<SeamailThread> completer) async {
      final FormData body = FormData()
        ..add('key', credentials.key);
      final String jsonBody = json.encode(<String, dynamic>{
        'users': users
          .where((User user) => user.username != credentials.username)
          .map<String>((User user) => user.username)
          .toList(),
        'subject': subject,
        'text': message,
      });
      final String result = await completer.chain<String>(
        _requestUtf8(
          'POST',
          'api/v2/seamail?${body.toUrlEncoded()}',
          body: utf8.encode(jsonBody),
          contentType: ContentType('application', 'json', charset: 'utf-8'),
        ),
      );
      final dynamic data = Json.parse(result);
      if (data['errors'] != null)
        throw ServerError((data.errors as Json).toList().cast<String>());
      final dynamic thread = data.seamail_meta;
      final String id = thread.id.toString();
      return SeamailThread(
        seamail: seamail,
        id: id,
        users: _parseUsersFromSeamailMeta(thread.users as Json, photoManager),
        messageCount: _parseMessageCount(thread.messages.toString()),
        subject: thread.subject.toString(),
        timestamp: DateTime.parse(thread.timestamp.toString()),
        unread: (thread.is_unread as Json).toBoolean(),
        messagesCallback: _getMessagesCallback(id, credentials),
        sendCallback: _getSendCallback(id, credentials),
      );
    });
  }

  List<User> _parseUsersFromSeamailMeta(Json users, PhotoManager photoManager) {
    return (users.asIterable()).map<User>((dynamic user) {
      photoManager.heardAboutUserPhoto(
        user.username.toString(),
        DateTime.fromMicrosecondsSinceEpoch((user.last_photo_updated as Json).toInt()),
      );
      return User(
        username: user.username.toString(),
        displayName: user.display_name.toString(),
      );
    }).toList();
  }

  int _parseMessageCount(String input) {
    if (input == '1 message')
      return 1;
    if (input.endsWith(' messages'))
      return int.parse(input.substring(0, input.length - 9));
    return null;
  }

  SeamailMessagesCallback _getMessagesCallback(String id, Credentials credentials) {
    return () { // TODO(ianh): pull this up to Twitarr-level rather than being a closure
      assert(credentials.key != null);
      final FormData body = FormData()
        ..add('key', credentials.key);
      return Progress<List<SeamailMessage>>((ProgressController<List<SeamailMessage>> completer) async {
        return await compute<String, List<SeamailMessage>>(
          _parseSeamailMessages,
          await completer.chain<String>(
            _requestUtf8('GET', 'api/v2/seamail/${Uri.encodeComponent(id)}?${body.toUrlEncoded()}'),
          ),
        );
      });
    };
  }

  static List<SeamailMessage> _parseSeamailMessages(String rawData) {
    final dynamic data = Json.parse(rawData);
    return (data.seamail.messages as Json).asIterable().map<SeamailMessage>((dynamic value) {
      return SeamailMessage(
        user: User(
          username: value.author.toString(),
          displayName: value.author_display_name.toString(),
        ),
        text: value.text.toString(),
        timestamp: DateTime.parse(value.timestamp.toString()),
      );
    }).toList().reversed.toList();
  }

  SeamailSendCallback _getSendCallback(String id, Credentials credentials) {
    return (String value) { // TODO(ianh): pull this up to Twitarr-level rather than being a closure
      return Progress<void>((ProgressController<void> completer) async {
        final FormData body = FormData()
          ..add('key', credentials.key)
          ..add('text', value);
        final String encodedBody = body.toUrlEncoded();
        final String result = await completer.chain<String>(_requestUtf8('POST', 'api/v2/seamail/${Uri.encodeComponent(id)}?$encodedBody'));
        final dynamic data = Json.parse(result);
        if (data['errors'] != null)
          throw ServerError((data.errors as Json).toList().cast<String>());
      });
    };
  }

  @override
  Progress<Uint8List> fetchProfilePicture(String username) {
    return _requestBytes('GET', 'api/v2/user/photo/${Uri.encodeComponent(username)}');
  }

  @override
  Progress<void> updateProfile({
    @required Credentials credentials,
    String currentLocation,
    String displayName,
    String email,
    bool emailPublic,
    String homeLocation,
    String realName,
    String roomNumber,
    bool vcardPublic,
  }) {
    assert(credentials != null);
    final FormData body = FormData()
      ..add('key', credentials.key);
    if (currentLocation != null) {
      body.add('current_location', currentLocation);
    }
    if (displayName != null) {
      assert(AuthenticatedUser.isValidDisplayName(displayName));
      body.add('display_name', displayName);
    }
    if (email != null) {
      assert(AuthenticatedUser.isValidEmail(email));
      body.add('email', email);
    }
    if (emailPublic != null) {
      body.add('email_public?', emailPublic ? 'true' : 'false');
    }
    if (homeLocation != null) {
      body.add('home_location', homeLocation);
    }
    if (realName != null) {
      body.add('real_name', realName);
    }
    if (roomNumber != null) {
      body.add('room_number', roomNumber);
    }
    if (vcardPublic != null) {
      body.add('vcard_public?', vcardPublic ? 'true' : 'false');
    }
    return Progress<AuthenticatedUser>((ProgressController<AuthenticatedUser> completer) async {
      final String result = await completer.chain<String>(_requestUtf8('POST', 'api/v2/user/profile?${body.toUrlEncoded()}'));
      final dynamic data = Json.parse(result);
      _checkStatusIsOk(data, desiredStatus: 'Profile Updated.');
    });
  }

  @override
  Progress<void> uploadAvatar({
    @required Credentials credentials,
    @required Uint8List bytes,
    @required PhotoManager photoManager,
  }) {
    assert(credentials != null);
    final FormData body = FormData()
      ..add('key', credentials.key)
      ..addFile('file', 'avatar.jpeg', bytes, ContentType('image', 'jpeg'));
    final MultipartFormData encoded = body.toMultipartEncoded();
    return Progress<void>((ProgressController<void> completer) async {
      final String result = await completer.chain<String>(_requestUtf8(
        'POST', 'api/v2/user/photo',
        bodyParts: encoded.body,
        contentType: encoded.contentType,
      ));
      final dynamic data = Json.parse(result);
      _checkStatusIsOk(data, statusIsHumanReadable: true);
    });
  }

  @override
  Progress<void> resetAvatar({
    @required Credentials credentials,
    @required PhotoManager photoManager
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
    return Progress<List<User>>((ProgressController<List<User>> completer) async {
      final List<User> result = await compute<String, List<User>>(
        _parseUserList,
        await completer.chain<String>(
          _requestUtf8('GET', 'api/v2/user/autocomplete/${Uri.encodeComponent(searchTerm)}'),
        ),
      );
      return result;
    });
  }

  static List<User> _parseUserList(String rawData) {
    final dynamic data = Json.parse(rawData);
    final Iterable<dynamic> values = (data.names as Json).asIterable();
    return values.map<User>((dynamic value) {
      return User(
        username: value.username.toString(),
        displayName: value.display_name.toString(),
      );
    }).toList();
  }

  Progress<String> _requestUtf8(String method, String path, {
    List<int> body,
    List<Uint8List> bodyParts,
    ContentType contentType,
    List<int> expectedStatusCodes = const <int>[200],
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
      return await response
        .map((List<int> bytes) {
          if (response.contentLength > 0) {
            count += bytes.length;
            completer.advance(count.toDouble(), response.contentLength.toDouble());
          }
          return bytes;
        })
        .transform(utf8.decoder)
        .join();
    });
  }

  Progress<Uint8List> _requestBytes(String method, String path, {
    List<int> body,
    List<Uint8List> bodyParts,
    ContentType contentType,
    List<int> expectedStatusCodes = const <int>[200],
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
    await Future<void>.delayed(Duration(milliseconds: debugLatency.round()));
    try {
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
      if (!expectedStatusCodes.contains(response.statusCode))
        throw HttpServerError(response.statusCode, response.reasonPhrase, url);
      if (_random.nextDouble() > debugReliability)
        throw const LocalError('Fake network failure');
      if (response.contentLength > 0)
        completer.advance(0.0, response.contentLength.toDouble());
      return response;
    } on SocketException catch (error) {
      if (error.osError.errorCode == 111)
        throw const ServerError(<String>['The server is down.']);
      rethrow;
    }
  }

  void _checkStatusIsOk(dynamic data, { String desiredStatus = 'ok', bool statusIsHumanReadable = false }) {
    if (data.status == 'key not valid')
      throw const ServerError(<String>['An authentication error occurred: the key the server provided is being refused for some reason. Try logging out and logging back in.']);
    if (data.status != desiredStatus) {
      if (statusIsHumanReadable)
        throw ServerError(<String>[data.status.toString()]);
      throw FormatException('status "${data.status}" is not "$desiredStatus"');
    }
  }

  @override
  void dispose() {
    _client.close(force: true);
  }
}
