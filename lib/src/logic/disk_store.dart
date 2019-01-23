import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import '../models/user.dart';
import '../progress.dart';
import 'store.dart';

export 'package:sqflite/sqflite.dart' show DatabaseException;

class DiskDataStore extends DataStore {
  DiskDataStore() : _database = _init();

  final Future<Database> _database;

  static Future<Database> _init() async {
    return await openDatabase(
      '${await getDatabasesPath()}/config.db',
      version: 3,
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
        await batch.commit(noResult: true);
      },
    );
  }

  @override
  Progress<void> saveCredentials(Credentials value) {
    return Progress<void>((ProgressController<void> completer) async {
      final Database database = await _database;
      await database.update('credentials', <String, dynamic>{
        'username': value.username,
        'password': value.password,
        'key': value.key,
        'loginTimestamp': value.loginTimestamp.millisecondsSinceEpoch,
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
        username: results['username'] as String,
        password: results['password'] as String,
        key: results['key'] as String,
        loginTimestamp: DateTime.fromMillisecondsSinceEpoch(results['loginTimestamp'] as int),
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
    return rows.map<String>((Map<String, dynamic> row) => row['message'] as String).toList();
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