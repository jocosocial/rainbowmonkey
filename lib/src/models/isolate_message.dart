import 'package:flutter/foundation.dart';

@immutable
abstract class IsolateMessage {
  const IsolateMessage();
}

class OpenSeamail extends IsolateMessage {
  const OpenSeamail(this.id);
  final String id;
}

class OpenCalendar extends IsolateMessage {
  const OpenCalendar();
}

class CheckMail extends IsolateMessage {
  const CheckMail();
}
