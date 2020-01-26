import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/user.dart';
import '../progress.dart';
import 'photo_manager.dart';
import 'store.dart';

export 'package:sqflite/sqflite.dart' show DatabaseException;

class DiskDataStore extends DataStore {
  DiskDataStore() : _database = _init();

  final Future<Database> _database;

  static Future<Database> _init() async {
    return await openDatabase(
      '${await getDatabasesPath()}/config.db',
      version: 5,
      onUpgrade: (Database database, int oldVersion, int newVersion) async {
        final Batch batch = database.batch();
        if (oldVersion < 1) {
          batch.execute('CREATE TABLE credentials (username STRING, password STRING, key STRING, loginTimestamp INTEGER)');
          batch.execute('INSERT INTO credentials DEFAULT VALUES');
        }
        if (oldVersion < 2) {
          batch.execute('CREATE TABLE settings (id INTEGER PRIMARY KEY, value BLOB)');
        }
        if (oldVersion < 3) {
          batch.execute('CREATE TABLE notifications (thread STRING NOT NULL, message STRING NOT NULL)');
        }
        if (oldVersion < 4) {
          batch.execute('CREATE TABLE userPhotos (id STRING PRIMARY KEY, value INTEGER NOT NULL)');
        }
        if (oldVersion < 5) {
          batch.execute('CREATE TABLE eventNotifications (event STRING NOT NULL)');
        }
        await batch.commit(noResult: true);
      },
    );
  }

  @override
  Progress<void> saveCredentials(Credentials value) {
    return Progress<void>((ProgressController<void> completer) async {
      final Database database = await _database;
      await database.update('credentials', <String, dynamic>{
        'username': value?.username,
        'password': value?.password,
        'key': value?.key,
        'loginTimestamp': value?.loginTimestamp?.millisecondsSinceEpoch,
      });
    });
  }

  @override
  Progress<Credentials> restoreCredentials() {
    return Progress<Credentials>((ProgressController<Credentials> completer) async {
      final Database database = await _database;
      final Map<String, dynamic> results = (await database.query(
        'credentials',
        columns: <String>['username', 'password', 'key', 'loginTimestamp'],
      )).single;
      if (results['username'] == null)
        return null;
      return Credentials(
        username: results['username'].toString(),
        password: (results['password'] ?? '').toString(), // Passwords may be numbers and dynamic may retrieve them as such.
        key: results['key'] as String,
        loginTimestamp: results['loginTimestamp'] != null ? DateTime.fromMillisecondsSinceEpoch(results['loginTimestamp'] as int) : null,
      );
    });
  }

  @override
  Progress<void> saveSetting(Setting id, dynamic value) {
    return Progress<void>((ProgressController<void> completer) async {
      final Uint8List bytes = _encodeValue(value);
      final Database database = await _database;
      await database.insert(
        'settings',
        <String, dynamic>{
          'id': id.index,
          'value': bytes,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  @override
  Progress<Map<Setting, dynamic>> restoreSettings() {
    return Progress<Map<Setting, dynamic>>((ProgressController<Map<Setting, dynamic>> completer) async {
      final Database database = await _database;
      final List<Map<String, dynamic>> rows = await database.query(
        'settings',
        columns: <String>['id', 'value'],
      );
      final Map<Setting, dynamic> result = <Setting, dynamic>{};
      for (Map<String, dynamic> row in rows) {
        final Setting id = Setting.values[row['id'] as int];
        result[id] = _decodeValueOf(row);
      }
      return result;
    });
  }

  @override
  Progress<dynamic> restoreSetting(Setting id) {
    return Progress<dynamic>((ProgressController<dynamic> completer) async {
      final Database database = await _database;
      final List<Map<String, dynamic>> rows = await database.rawQuery(
        'SELECT value FROM settings WHERE id=?',
        <dynamic>[id.index],
      );
      if (rows.isEmpty)
        return null;
      return _decodeValueOf(rows.single);
    });
  }

  @override
  Future<void> addNotification(String threadId, String messageId) async {
    final Database database = await _database;
    await database.insert(
      'notifications',
      <String, dynamic>{
        'thread': threadId,
        'message': messageId,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> removeNotification(String threadId, String messageId) async {
    final Database database = await _database;
    await database.delete(
      'notifications',
      where: 'thread=? AND message=?',
      whereArgs: <dynamic>[ threadId, messageId ],
    );
  }

  @override
  Future<List<String>> getNotifications(String threadId) async {
    final Database database = await _database;
    final List<Map<String, dynamic>> rows = await database.rawQuery(
      'SELECT message FROM notifications WHERE thread=?',
      <dynamic>[threadId],
    );
    return rows.map<String>((Map<String, dynamic> row) => row['message'].toString()).toList();
  }

  @override
  Future<void> addEventNotification(String eventId) async {
    final Database database = await _database;
    await database.insert(
      'eventNotifications',
      <String, dynamic>{
        'event': eventId,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<bool> didShowEventNotification(String eventId) async {
    final Database database = await _database;
    final List<Map<String, dynamic>> rows = await database.rawQuery(
      'SELECT event FROM eventNotifications WHERE event=?',
      <dynamic>[eventId],
    );
    return rows.isNotEmpty;
  }

  @override
  Future<void> updateFreshnessToken(FreshnessCallback callback) async {
    assert(callback != null);
    final Database database = await _database;
    await database.transaction((Transaction transaction) async {
      final List<Map<String, dynamic>> rows = await transaction.rawQuery(
        'SELECT value FROM settings WHERE id=?',
        <dynamic>[Setting.notificationFreshnessToken.index],
      );
      final int newValue = await callback(rows.isEmpty ? null : _decodeValueOf(rows.single) as int);
      await transaction.insert(
        'settings',
        <String, dynamic>{
          'id': Setting.notificationFreshnessToken.index,
          'value': _encodeValue(newValue),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  @override
  Future<void> heardAboutUserPhoto(String id, DateTime updateTime) async {
    final Database database = await _database;
    await database.insert(
      'userPhotos',
      <String, dynamic>{
        'id': id,
        'value': updateTime.toUtc().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<Map<String, DateTime>> restoreUserPhotoList() async {
    final Database database = await _database;
    final List<Map<String, dynamic>> rows = await database.query(
      'userPhotos',
      columns: <String>['id', 'value'],
    );
    final Map<String, DateTime> result = <String, DateTime>{};
    for (Map<String, dynamic> row in rows) {
      result[row['id'].toString()] = DateTime.fromMillisecondsSinceEpoch(row['value'] as int, isUtc: true);
    }
    return result;
  }

  static String _encodePhotoKey(String serverKey, String cacheName, String photoId) {
    return '$serverKey $cacheName $photoId';
  }

  Future<String> _keyToPath(String key) async {
    return path.join((await getTemporaryDirectory()).path, 'photo_store', base64.encode(utf8.encode(key)).replaceAll('/', '-'));
  }

  Future<_BytesAndFile> _putImageIfAbsent(String serverKey, String cacheName, String photoId, ImageFetcher callback) async {
    Uint8List bytes;
    final String key = _encodePhotoKey(serverKey, cacheName, photoId);
    final File cache = File(await _keyToPath(key));
    try {
      bytes = await cache.readAsBytes();
    } on FileSystemException {
      bytes = await callback();
      try {
        await cache.create(recursive: true);
        await cache.writeAsBytes(bytes);
      } on FileSystemException catch (error) {
        debugPrint('Failed to cache "$key": $error');
      }
    }
    return _BytesAndFile(bytes, cache);
  }

  @override
  Future<Uint8List> putImageIfAbsent(String serverKey, String cacheName, String photoId, ImageFetcher callback) async {
    return (await _putImageIfAbsent(serverKey, cacheName, photoId, callback)).bytes;
  }

  @override
  Future<File> putImageFileIfAbsent(String serverKey, String cacheName, String photoId, ImageFetcher callback) async {
    return (await _putImageIfAbsent(serverKey, cacheName, photoId, callback)).file;
  }

  @override
  Future<void> removeImage(String serverKey, String cacheName, String photoId) async {
    try {
      await File(await _keyToPath(_encodePhotoKey(serverKey, cacheName, photoId))).delete();
    } on FileSystemException {
      // ignore errors
    }
  }

  Uint8List _encodeValue(dynamic value) {
    final ByteData encodedValue = const StandardMessageCodec().encodeMessage(value);
    return encodedValue.buffer.asUint8List(
      encodedValue.offsetInBytes,
      encodedValue.lengthInBytes,
    );
  }

  dynamic _decodeValueOf(Map<String, dynamic> row) {
    final Uint8List bytes = row['value'] as Uint8List;
    final ByteData data = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);
    final dynamic value = const StandardMessageCodec().decodeMessage(data);
    return value;
  }
}

class _BytesAndFile {
  _BytesAndFile(this.bytes, this.file);
  final Uint8List bytes;
  final File file;
}