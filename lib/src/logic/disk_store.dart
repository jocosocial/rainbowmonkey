import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import '../models/user.dart';
import '../progress.dart';
import 'store.dart';

class DiskDataStore extends DataStore {
  DiskDataStore() : _database = _init();

  final Future<Database> _database;

  static Future<Database> _init() async {
    return await openDatabase(
      '${await getDatabasesPath()}/config.db',
      version: 2,
      onUpgrade: (Database database, int oldVersion, int newVersion) async {
        final Batch batch = database.batch();
        if (oldVersion < 1) {
          batch.execute('CREATE TABLE credentials (username STRING, password STRING, key STRING, loginTimestamp INTEGER)');
          batch.execute('INSERT INTO credentials DEFAULT VALUES');
        }
        if (oldVersion < 2) {
          batch.execute('CREATE TABLE settings (id INTEGER PRIMARY KEY, value BLOB)');
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
      final ByteData encodedValue = const StandardMessageCodec().encodeMessage(value);
      final Uint8List bytes = encodedValue.buffer.asUint8List(
        encodedValue.offsetInBytes,
        encodedValue.lengthInBytes,
      );
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
        final Uint8List bytes = row['value'] as Uint8List;
        final ByteData data = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);
        final dynamic value = const StandardMessageCodec().decodeMessage(data);
        result[id] = value;
      }
      return result;
    });
  }
}