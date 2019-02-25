import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';

typedef ImageFetcher = Future<Uint8List> Function();

abstract class PhotoManager {
  Future<Uint8List> putImageIfAbsent(String id, ImageFetcher callback, { @required bool thumbnail });
  Future<Uint8List> putUserPhotoIfAbsent(String username, ImageFetcher callback);
  void heardAboutUserPhoto(String username, DateTime lastUpdate);
  void addListenerForUserPhoto(String username, VoidCallback listener);
  void removeListenerForUserPhoto(String username, VoidCallback listener);
}

class Photo {
  const Photo({
    this.id,
    this.size,
    this.mediumSize,
  });

  final String id;

  final Size size;

  final Size mediumSize;

  bool get hasThumbnail => size != mediumSize;
}
