import 'package:flutter/foundation.dart';

@immutable
class TwitarrString {
  const TwitarrString(this.encodedValue);

  final String encodedValue;

  @override
  String toString() => encodedValue;
}
