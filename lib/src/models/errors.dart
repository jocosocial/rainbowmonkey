abstract class UserFriendlyError { }

typedef ErrorCallback = void Function(UserFriendlyError error);

class LocalError implements Exception, UserFriendlyError {
  const LocalError(this.message);

  final String message;

  @override
  String toString() => message;
}

class ServerError implements Exception, UserFriendlyError {
  const ServerError(this.messages) : assert(messages != null);

  final List<String> messages;

  @override
  String toString() => messages.join('\n');
}

class InvalidUsernameOrPasswordError implements Exception, UserFriendlyError {
  const InvalidUsernameOrPasswordError();

  @override
  String toString() => 'Server did not recognize the username or password.';
}

class InvalidUserAndRegistrationCodeError implements Exception, UserFriendlyError {
  const InvalidUserAndRegistrationCodeError();

  @override
  String toString() => 'Either that account does not exist or that is the wrong registration code.';
}

class FeatureDisabledError implements Exception, UserFriendlyError {
  const FeatureDisabledError();

  @override
  String toString() => 'This feature has been disabled on the server.';
}

class FieldErrors implements Exception {
  const FieldErrors(this.fields);

  final Map<String, List<String>> fields;

  @override
  String toString() => 'Account creation failed:\n$fields';
}

class HttpServerError implements Exception, UserFriendlyError {
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
      case 504: return 'Server is having problems (it said "$reasonPhrase").\nTry again later.';
      case 401:
      case 403: return 'There was an authentication problem (server said "$reasonPhrase").\nTry logging in again.';
      case 400:
      case 405: return 'There is probably a bug (server said "$reasonPhrase").\nTry again, maybe?';
      default: return 'There was an unexpected error. The server said "$statusCode $reasonPhrase".';
    }
  }
}
