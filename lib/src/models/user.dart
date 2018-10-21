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

class User {
  const User({ this.username, this.email, this.credentials });

  final String username;
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
    return password.length >= 6;
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
}
