import 'dart:convert';
import 'dart:io';
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
  bool operator ==(dynamic other) {
    if (other.runtimeType != runtimeType)
      return false;
    final RestTwitarrConfiguration typedOther = other;
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
    _client = new HttpClient();
    _parsedBaseUrl = Uri.parse(baseUrl);
  }

  final String baseUrl;

  @override
  TwitarrConfiguration get configuration => RestTwitarrConfiguration(baseUrl: baseUrl);

  HttpClient _client;
  Uri _parsedBaseUrl;

  @override
  Progress<AuthenticatedUser> createAccount({
    @required String username,
    @required String password,
    @required String email,
    @required String securityQuestion,
    @required String securityAnswer,
  }) {
    assert(username != null);
    assert(password != null);
    assert(email != null);
    assert(securityAnswer != null);
    assert(securityQuestion != null);
    assert(AuthenticatedUser.isValidUsername(username));
    assert(AuthenticatedUser.isValidDisplayName(username));
    assert(AuthenticatedUser.isValidPassword(password));
    assert(AuthenticatedUser.isValidEmail(email));
    assert(AuthenticatedUser.isValidSecurityQuestion(securityQuestion));
    assert(AuthenticatedUser.isValidSecurityAnswer(securityAnswer));
    final FormData body = new FormData()
      ..add('new_username', username)
      ..add('new_password', password)
      ..add('email', email)
      ..add('security_question', securityQuestion)
      ..add('security_answer', securityAnswer);
    return new Progress<AuthenticatedUser>((ProgressController<AuthenticatedUser> completer) async {
      final String result = await completer.chain<String>(_requestUtf8('POST', 'api/v2/user/new?${body.toUrlEncoded()}'));
      final dynamic data = Json.parse(result);
      _checkForCommonServerErrors(data);
      final String key = data.key.toString();
      return new AuthenticatedUser(
        username: username,
        // TODO(ianh): do something with the data.user field
        credentials: new Credentials(
          username: username,
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
    return new Progress<AuthenticatedUser>((ProgressController<AuthenticatedUser> completer) async {
      final FormData body = new FormData()
        ..add('username', username)
        ..add('password', password);
      final String result = await completer.chain<String>(_requestUtf8('GET', 'api/v2/user/auth?${body.toUrlEncoded()}'), steps: 2);
      final dynamic data = Json.parse(result);
      if (data.status == 'incorrect password or username')
        throw const InvalidUsernameOrPasswordError();
      _checkForCommonServerErrors(data);
      final String key = data.key.toString();
      return completer.chain<AuthenticatedUser>(getAuthenticatedUser(
        new Credentials(
          username: username,
          password: password,
          key: key,
          loginTimestamp: new DateTime.now(),
        ),
        photoManager,
      ));
    });
  }

  @override
  Progress<AuthenticatedUser> logout() {
    return new Progress<AuthenticatedUser>((ProgressController<AuthenticatedUser> completer) async {
      await completer.chain<String>(_requestUtf8('POST', 'api/v2/user/logout'), steps: 2);
      return null;
    });
  }

  @override
  Progress<AuthenticatedUser> getAuthenticatedUser(Credentials credentials, PhotoManager photoManager) {
    assert(credentials.key != null);
    return new Progress<AuthenticatedUser>((ProgressController<AuthenticatedUser> completer) async {
      final FormData body = new FormData()
        ..add('key', credentials.key);
      final String rawResult = await completer.chain<String>(_requestUtf8('GET', 'api/v2/user/whoami?${body.toUrlEncoded()}'));
      final dynamic data = Json.parse(rawResult);
      _checkForCommonServerErrors(data);
      photoManager.heardAboutUserPhoto(
        data.user.username.toString(),
        new DateTime.fromMicrosecondsSinceEpoch((data.user.last_photo_updated as Json).toInt()),
      );
      return new AuthenticatedUser(
        username: data.user.username.toString(),
        email: data.user.email.toString(),
        displayName: data.user.display_name.toString(),
        // other available fields:
        //  - is_admin
        //  - status ("active")
        //  - email_public
        //  - vcard_public
        //  - current_location
        //  - last_login
        //  - empty_password
        //  - room_number
        //  - real_name
        //  - home_location
        //  - unnoticed_alerts
        credentials: credentials,
      );
    });
  }

  @override
  Progress<Calendar> getCalendar() {
    return new Progress<Calendar>((ProgressController<Calendar> completer) async {
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
    final dynamic values = data.event.asIterable().single;
    if (values.status != 'ok')
      throw const FormatException('status invalid');
    if (values.total_count != (values.events.asIterable() as Iterable<dynamic>).length)
      throw const FormatException('total_count invalid');
    return new Calendar(events: (values.events.asIterable() as Iterable<dynamic>).map<Event>((dynamic value) {
      return new Event(
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
    final FormData body = new FormData()
      ..add('key', credentials.key);
    final String encodedBody = body.toUrlEncoded();
    final String rawResult = await _requestUtf8('GET', 'api/v2/seamail?$encodedBody').asFuture();
    if (cancelationSignal.canceled)
      return;
    final dynamic data = Json.parse(rawResult);
    seamail.update(new DateTime.fromMicrosecondsSinceEpoch((data.last_checked as Json).toInt()), (SeamailUpdater updater) {
      for (dynamic thread in data.seamail_meta.asIterable()) {
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
    return new Progress<SeamailThread>((ProgressController<SeamailThread> completer) async {
      final FormData body = new FormData()
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
          contentType: new ContentType('application', 'json'),
        ),
      );
      final dynamic data = Json.parse(result);
      if (data['errors'] != null)
        throw new ServerError(data.errors.asIterable().map<String>((Json value) => value.toString()).toList() as List<String>);
      final dynamic thread = data.seamail_meta;
      final String id = thread.id.toString();
      return new SeamailThread(
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
    return users.asIterable().map<User>((dynamic user) {
      photoManager.heardAboutUserPhoto(
        user.username.toString(),
        new DateTime.fromMicrosecondsSinceEpoch((user.last_photo_updated as Json).toInt()),
      );
      return new User(
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
      final FormData body = new FormData()
        ..add('key', credentials.key);
      return new Progress<List<SeamailMessage>>((ProgressController<List<SeamailMessage>> completer) async {
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
      return new SeamailMessage(
        user: new User(
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
      return new Progress<void>((ProgressController<void> completer) async {
        final FormData body = new FormData()
          ..add('key', credentials.key)
          ..add('text', value);
        final String encodedBody = body.toUrlEncoded();
        final String result = await completer.chain<String>(_requestUtf8('POST', 'api/v2/seamail/${Uri.encodeComponent(id)}/new_message?$encodedBody'));
        final dynamic data = Json.parse(result);
        if (data['errors'] != null)
          throw new ServerError(data.errors.asIterable().map<String>((Json value) => value.toString()).toList() as List<String>);
      });
    };
  }

  @override
  Progress<Uint8List> fetchProfilePicture(String username) {
    return _requestBytes('GET', 'api/v2/user/photo/${Uri.encodeComponent(username)}');
  }

  @override
  Progress<List<User>> getUserList(String searchTerm) {
    return new Progress<List<User>>((ProgressController<List<User>> completer) async {
      final FormData body = new FormData()
        ..add('string', searchTerm);
      final List<User> result = await compute<String, List<User>>(
        _parseUserList,
        await completer.chain<String>(
          _requestUtf8('GET', 'user/autocomplete?${body.toUrlEncoded()}'),
        ),
      );
      if (result == null) // TODO(ianh): remove this once https://github.com/flutter/flutter/pull/24848 lands
        throw new Exception('Error');
      return result;
    });
  }

  static List<User> _parseUserList(String rawData) {
    final dynamic data = Json.parse(rawData);
    final Iterable<dynamic> values = data.names.asIterable();
    return values.map<User>((dynamic value) {
      return new User(
        username: value.username.toString(),
        displayName: value.display_name.toString(),
      );
    }).toList();
  }

  Progress<String> _requestUtf8(String method, String path, { List<int> body, ContentType contentType }) {
    return new Progress<String>((ProgressController<String> completer) async {
      final HttpClientResponse response = await _requestInternal<String>(completer, method, path, body, contentType);
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

  Progress<Uint8List> _requestBytes(String method, String path, { List<int> body, ContentType contentType }) {
    return new Progress<Uint8List>((ProgressController<Uint8List> completer) async {
      final HttpClientResponse response = await _requestInternal<Uint8List>(completer, method, path, body, contentType);
      int count = 0;
      final List<List<int>> chunks = <List<int>>[];
      await response.forEach((List<int> chunk) {
        count += chunk.length;
        if (response.contentLength > 0)
          completer.advance(count.toDouble(), response.contentLength.toDouble());
        chunks.add(chunk);
      });
      final Uint8List bytes = new Uint8List(count);
      int offset = 0;
      for (List<int> chunk in chunks) {
        bytes.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      }
      return bytes;
    });
  }

  Future<HttpClientResponse> _requestInternal<T>(ProgressController<T> completer, String method, String path, List<int> body, ContentType contentType) async {
    assert(body != null || contentType == null);
    final Uri url = _parsedBaseUrl.resolve(path);
    assert(() {
      debugPrint('>>> $method $url (body length: ${body?.length})');
      return true;
    }());
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final HttpClientRequest request = await _client.openUrl(method, url);
    if (body != null) {
      if (contentType != null)
        request.headers.contentType = contentType;
      request.add(body);
    }
    final HttpClientResponse response = await request.close();
    if (response.contentLength > 0)
      completer.advance(0.0, response.contentLength.toDouble());
    return response;
  }

  void _checkForCommonServerErrors(dynamic data) {
    if (data['errors'] != null)
      throw new ServerError(data.errors.asIterable().map<String>((Json value) => value.toString()).toList() as List<String>);
    if (data.status == 'key not valid')
      throw const ServerError(<String>['An authentication error occurred: the key the server provided is being refused for some reason. Try logging out and logging back in.']);
    if (data.status != 'ok')
      throw const FormatException('status invalid');
  }

  @override
  void dispose() {
    _client.close(force: true);
  }
}
