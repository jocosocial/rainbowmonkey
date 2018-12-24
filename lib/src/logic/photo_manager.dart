import 'dart:typed_data';

typedef PhotoFetcher = Future<Uint8List> Function();

abstract class PhotoManager {
  Future<Uint8List> putIfAbsent(String username, PhotoFetcher callback);
  void heardAboutUserPhoto(String username, DateTime lastUpdate);
}
