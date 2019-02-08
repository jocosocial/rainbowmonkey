import 'package:cruisemonkey/src/network/twitarr.dart';

class NullTwitarrConfiguration extends TwitarrConfiguration {
  const NullTwitarrConfiguration();

  @override
  Twitarr createTwitarr() => null;

  static void register() {
    TwitarrConfiguration.register(_prefix, _factory);
  }

  static const String _prefix = 'null';

  static NullTwitarrConfiguration _factory(String settings) {
    return const NullTwitarrConfiguration();
  }

  @override
  String get prefix => _prefix;

  @override
  String get settings => '';
}
