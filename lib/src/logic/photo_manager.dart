import 'dart:typed_data';

import 'package:flutter/foundation.dart';

typedef PhotoFetcher = Future<Uint8List> Function();

abstract class PhotoManager {
  Future<Uint8List> putIfAbsent(String username, PhotoFetcher callback);
  void heardAboutUserPhoto(String username, DateTime lastUpdate);
  void addListenerForPhoto(String username, VoidCallback listener);
  void removeListenerForPhoto(String username, VoidCallback listener);
}
