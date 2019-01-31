import 'dart:typed_data';

import 'package:flutter/foundation.dart';

typedef ImageFetcher = Future<Uint8List> Function();

abstract class PhotoManager {
  Future<Uint8List> putImageIfAbsent(String id, ImageFetcher callback);
  Future<Uint8List> putUserPhotoIfAbsent(String username, ImageFetcher callback);
  void heardAboutUserPhoto(String username, DateTime lastUpdate);
  void addListenerForUserPhoto(String username, VoidCallback listener);
  void removeListenerForUserPhoto(String username, VoidCallback listener);
}
