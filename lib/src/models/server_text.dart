import 'package:flutter/foundation.dart';

@immutable
class ServerText {
  const ServerText(this.sections);

  final List<ServerTextSection> sections;
}

@immutable
class ServerTextSection {
  const ServerTextSection({ this.header, this.paragraphs });

  final String header;

  final List<ServerTextParagraph> paragraphs;
}

@immutable
class ServerTextParagraph {
  const ServerTextParagraph(this.text, { this.hasBullet = false }) : assert(hasBullet != null);

  final String text;

  final bool hasBullet;
}
