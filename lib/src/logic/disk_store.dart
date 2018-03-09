import '../models/user.dart';
import '../progress.dart';
import 'store.dart';

class DiskDataStore extends DataStore {
  @override
  Progress<void> saveCredentials(Credentials value) {
    return new Progress<void>((ProgressController<void> completer) async {
      // value.username
      // value.password (password can contain newlines, nulls, etc)
      // value.key
      // value.loginTimestamp?.millisecondsSinceEpoch
      return null;
    });
  }

  @override
  Progress<Credentials> restoreCredentials() {
    return new Progress<Credentials>((ProgressController<Credentials> completer) async {
      // result.update(new Credentials(
      //   username: 'Test',
      //   password: 'test',
      //   key: null,
      //   loginTimestamp: new DateTime.fromMillisecondsSinceEpoch(int.parse('0')),
      // ));
      return null;
    });
  }
}
