import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../json.dart';
import '../models/calendar.dart';
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

/// An implementation of [Twitarr] that uses the /api/v2/ HTTP protocol
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
  Progress<User> createAccount({
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
    assert(User.isValidUsername(username));
    assert(User.isValidDisplayName(username));
    assert(User.isValidPassword(password));
    assert(User.isValidEmail(email));
    assert(User.isValidSecurityQuestion(securityQuestion));
    assert(User.isValidSecurityAnswer(securityAnswer));
    final FormData body = new FormData()
      ..add('new_username', username)
      ..add('new_password', password)
      ..add('email', email)
      ..add('security_question', securityQuestion)
      ..add('security_answer', securityAnswer);
    return new Progress<User>((ProgressController<User> completer) async {
      final String result = await completer.chain<String>(_request('POST', 'api/v2/user/new?${body.toUrlEncoded()}'));
      // TODO(ianh): handle specific known error responses (e.g. "user already exists") in a structured manner
      final dynamic data = Json.parse(result);
      if (data['errors'] != null)
        throw new ServerError(data.errors.asIterable().map<String>((Json value) => value.toString()).toList() as List<String>);
      if (data.status != 'ok')
        throw const FormatException('status invalid');
      final String key = data.key.toString();
      return new User(
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
  Progress<User> login({
    @required String username,
    @required String password,
  }) {
    assert(username != null);
    assert(password != null);
    assert(User.isValidUsername(username));
    assert(User.isValidPassword(password));
    return new Progress<User>((ProgressController<User> completer) async {
      final FormData body = new FormData()
        ..add('username', username)
        ..add('password', password);
      final String result = await completer.chain<String>(_request('GET', 'api/v2/user/auth?${body.toUrlEncoded()}'), steps: 2);
      try {
        // TODO(ianh): handle specific known error responses (e.g. "incorrect password or username") in a structured manner
        final dynamic data = Json.parse(result);
        if (data.status == 'incorrect password or username')
          throw const InvalidUsernameOrPasswordError();
        if (data.status != 'ok')
          throw const FormatException('status invalid');
        final String key = data.key.toString();
        return completer.chain<User>(getAuthenticatedUser(new Credentials(
          username: username,
          password: password,
          key: key,
          loginTimestamp: new DateTime.now(),
        )));
      } on FormatException catch (error) {
        debugPrint('GET api/v2/user/auth: $error');
        debugPrint('----8<----');
        debugPrint(result);
        debugPrint('----8<----');
        rethrow;
      }
    });
  }

  @override
  Progress<User> logout() {
    return new Progress<User>((ProgressController<User> completer) async {
      await completer.chain<String>(_request('POST', 'api/v2/user/logout'), steps: 2);
      return null;
    });
  }

  @override
  Progress<User> getAuthenticatedUser(Credentials credentials) {
    assert(credentials.key != null);
    return new Progress<User>((ProgressController<User> completer) async {
      final FormData body = new FormData()
        ..add('key', credentials.key);
      final String rawResult = await completer.chain<String>(_request('GET', 'api/v2/user/whoami?${body.toUrlEncoded()}'));
      try {
        // TODO(ianh): handle specific known error responses (e.g. "key not valid") in a structured manner
        final dynamic data = Json.parse(rawResult);
        if (data['errors'] != null)
          throw new ServerError(data.errors.asIterable().map<String>((Json value) => value.toString()).toList() as List<String>);
        if (data.status != 'ok')
          throw const FormatException('status invalid');
        return new User(
          username: credentials.username,
          // TODO(ianh): parse the data.user field and return it
          credentials: credentials,
        );
      } on FormatException catch (error) {
        debugPrint('GET api/v2/user/whoami: $error');
        debugPrint('----8<----');
        debugPrint(rawResult);
        debugPrint('----8<----');
        rethrow;
      }
    });
  }

  @override
  Progress<Calendar> getCalendar() {
    return new Progress<Calendar>((ProgressController<Calendar> completer) async {
      return await compute(
        _parseCalendar,
        await completer.chain<String>(
          _request('GET', '/api/v2/event.json'),
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
        official: value.official.toBoolean() as bool,
        description: value['description']?.toString(),
        location: value.location.toString(),
        startTime: DateTime.parse(value.start_time.toString()),
        endTime: DateTime.parse(value.end_time.toString()),
      );
    }).toList());
  }

  Progress<String> _request(String method, String path, { List<int> body }) {
    return new Progress<String>((ProgressController<String> completer) async {
      final HttpClientRequest request = await _client.openUrl(method, _parsedBaseUrl.resolve(path));
      if (body != null)
        request.add(body);
      final HttpClientResponse response = await request.close();
      if (response.contentLength > 0)
        completer.advance(0.0, response.contentLength.toDouble());
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

  @override
  void dispose() {
    _client.close(force: true);
  }
}
