import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:cruisemonkey/network.dart';
import 'package:cruisemonkey/models.dart';

class TestTwitarr extends Twitarr {
  @override
  ValueNotifier<Calendar> calendar = new ValueNotifier<Calendar>(null);

  @override
  void dispose() { }
}
