import 'dart:convert';

class _FormDataPair {
  const _FormDataPair(this.name, this.value);
  final String name;
  final String value;
}

class FormData {
  FormData();

  final List<_FormDataPair> _data = <_FormDataPair>[];

  /// Delete all the name-value pairs.
  void clear() {
    _data.clear();
  }

  void add(String name, String value) {
    _data.add(new _FormDataPair(name, value));
  }

  /// Returns the encoded data as a `x-www-form-urlencoded` string.
  ///
  /// The `encoding` argument controls the encoding used to %-encode the data.
  String toUrlEncoded({ Encoding encoding: utf8 }) {
    final StringBuffer result = new StringBuffer();
    bool delimit = false;
    for (_FormDataPair pair in _data) {
      if (delimit)
        result.write('&');
      result
        ..write(Uri.encodeQueryComponent(pair.name, encoding: encoding))
        ..write('=')
        ..write(Uri.encodeQueryComponent(pair.value, encoding: encoding));
      delimit = true;
    }
    return result.toString();
  }
}