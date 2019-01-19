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
      version: 1,
      onUpgrade: (Database database, int oldVersion, int newVersion) async {
        final Batch batch = database.batch();
        if (oldVersion < 1) {
          batch.execute('CREATE TABLE credentials (username STRING, password STRING, key STRING, loginTimestamp INTEGER)');
          batch.execute('INSERT INTO credentials DEFAULT VALUES');
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
}