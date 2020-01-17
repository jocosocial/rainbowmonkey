import 'package:flutter/foundation.dart';

import 'string.dart';

@immutable
class ServerText {
  const ServerText(this.sections);

  final List<ServerTextSection> sections;
}

@immutable
class ServerTextSection {
  const ServerTextSection({ this.header, this.paragraphs });

  final TwitarrString header;

  final List<ServerTextParagraph> paragraphs;
}

@immutable
class ServerTextParagraph {
  const ServerTextParagraph(this.text, { this.hasBullet = false }) : assert(hasBullet != null);

  final TwitarrString text;

  final bool hasBullet;
}
