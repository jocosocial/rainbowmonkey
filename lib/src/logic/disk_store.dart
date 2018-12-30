import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/user.dart';
import '../progress.dart';
import 'store.dart';

class DiskDataStore extends DataStore {
  final MessageCodec<dynamic> _codec = _CredentialsCodec();

  Future<File> get _config async {
    return File('${(await getApplicationDocumentsDirectory()).path}/config.dat');
  }

  @override
  Progress<void> saveCredentials(Credentials value) {
    return Progress<void>((ProgressController<void> completer) async {
      final ByteData data = _codec.encodeMessage(value);
      await (await _config).writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    });
  }

  @override
  Progress<Credentials> restoreCredentials() {
    return Progress<Credentials>((ProgressController<Credentials> completer) async {
      final File config = await _config;
      if (await config.exists()) {
        final Credentials result = _codec.decodeMessage(ByteData.view((await (await _config).readAsBytes() as Uint8List).buffer)) as Credentials;
        return result;
      }
      return null;
    });
  }
}

class _CredentialsCodec extends StandardMessageCodec {
  static const int _valueCredentials = 128;
  static const int _valueDateTime = 129;

  @override
  void writeValue(WriteBuffer buffer, dynamic value) {
    if (value is Credentials) {
      _writeCredentials(buffer, value);
    } else if (value is DateTime) {
      _writeDateTime(buffer, value);
    } else {
      super.writeValue(buffer, value);
    }
  }

  void _writeCredentials(WriteBuffer buffer, Credentials value) {
    buffer.putUint8(_valueCredentials);
    writeValue(buffer, value.username);
    writeValue(buffer, value.password);
    writeValue(buffer, value.key);
    writeValue(buffer, value.loginTimestamp);
  }

  void _writeDateTime(WriteBuffer buffer, DateTime value) {
    buffer.putUint8(_valueDateTime);
    writeValue(buffer, value.millisecondsSinceEpoch);
  }

  @override
  dynamic readValueOfType(int type, ReadBuffer buffer) {
    switch (type) {
      case _valueCredentials:
        return Credentials(
          username: _readValue<String>(buffer),
          password: _readValue<String>(buffer),
          key: _readValue<String>(buffer),
          loginTimestamp: _readValue<DateTime>(buffer),
        );
      case _valueDateTime:
        return DateTime.fromMillisecondsSinceEpoch(_readValue<int>(buffer));
      default:
        return super.readValueOfType(type, buffer);
    }
  }

  T _readValue<T>(ReadBuffer buffer) {
    final T value = readValue(buffer) as T;
    return value;
  }
}