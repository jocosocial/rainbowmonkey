import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:cruisemonkey/src/network/network.dart';
import 'package:cruisemonkey/src/models/calendar.dart';

class TestTwitarr extends Twitarr {
  @override
  ValueNotifier<Calendar> calendar = new ValueNotifier<Calendar>(null);

  @override
  void dispose() { }
}
