import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

abstract class _FormDataItem {
  const _FormDataItem(this.name);
  final String name;
  String get value;
}

class _FormDataField extends _FormDataItem {
  const _FormDataField(String name, this.value) : super(name);
  @override
  final String value;
}

class _FormDataFile extends _FormDataItem {
  const _FormDataFile(String name, this.value, this.bytes, this.contentType) : super(name);
  @override
  final String value; // file name
  final Uint8List bytes;
  final ContentType contentType;
}

class FormData {
  FormData();

  final List<_FormDataItem> _data = <_FormDataItem>[];

  /// Delete all the name-value pairs.
  void clear() {
    _data.clear();
  }

  void add(String name, String value) {
    _data.add(_FormDataField(name, value));
  }

  void addFile(String name, String filename, Uint8List bytes, ContentType contentType) {
    _data.add(_FormDataFile(name, filename, bytes, contentType));
  }

  void addImage(String name, Uint8List bytes) {
    ContentType type;
    String filename;
    if (bytes.length >= 6 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x38 &&
        (bytes[4] == 0x39 || bytes[4] == 0x37) &&
        bytes[5] == 0x61) {
      type = ContentType('image', 'gif');
      filename = 'image.gif';
    } else if (bytes.length >= 8 &&
               bytes[0] == 0x89 &&
               bytes[1] == 0x50 &&
               bytes[2] == 0x4E &&
               bytes[3] == 0x47 &&
               bytes[4] == 0x0D &&
               bytes[5] == 0x0A &&
               bytes[6] == 0x1A &&
               bytes[7] == 0x0A) {
      type = ContentType('image', 'png');
      filename = 'image.png';
    } else {
      type = ContentType('image', 'jpeg');
      filename = 'image.jpeg';
    }
    addFile(name, filename, bytes, type);
  }

  /// Returns the encoded data as a `x-www-form-urlencoded` string.
  ///
  /// The `encoding` argument controls the encoding used to %-encode the data.
  ///
  /// Files are reduced to their file name. Use `toMultipartEncoded` for data
  /// containing files.
  String toUrlEncoded({ Encoding encoding: utf8 }) {
    final StringBuffer result = StringBuffer();
    bool delimit = false;
    for (_FormDataItem item in _data) {
      if (delimit)
        result.write('&');
      result
        ..write(Uri.encodeQueryComponent(item.name, encoding: encoding))
        ..write('=')
        ..write(Uri.encodeQueryComponent(item.value, encoding: encoding));
      delimit = true;
    }
    return result.toString();
  }

  MultipartFormData toMultipartEncoded() {
    final String boundary = _generateBoundary(70, math.Random.secure());
    final Uint8List fullBoundary = utf8.encode('\r\n--$boundary') as Uint8List;
    final Uint8List contentDispositionHeader = utf8.encode('\r\nContent-Disposition: form-data; name="') as Uint8List;
    final Uint8List closeQuote = utf8.encode('"') as Uint8List;
    final Uint8List filenameParameter = utf8.encode('; filename="') as Uint8List;
    final Uint8List contentTypeHeader = utf8.encode('\r\nContent-Type: ') as Uint8List;
    final Uint8List blankLine = utf8.encode('\r\n\r\n') as Uint8List;
    final Uint8List finalBoundary = utf8.encode('--\r\n') as Uint8List;
    final List<Uint8List> parts = <Uint8List>[];
    for (_FormDataItem item in _data) {
      parts.add(fullBoundary);
      parts.add(contentDispositionHeader);
      parts.add(utf8.encode(item.name) as Uint8List);
      parts.add(closeQuote);
      if (item is _FormDataFile) {
        parts.add(filenameParameter);
        parts.add(utf8.encode(item.value) as Uint8List);
        parts.add(closeQuote);
        parts.add(contentTypeHeader);
        parts.add(utf8.encode(item.contentType.value) as Uint8List);
      }
      parts.add(blankLine);
      if (item is _FormDataFile) {
        parts.add(item.bytes);
      } else {
        assert(item is _FormDataField);
        parts.add(utf8.encode(item.value) as Uint8List);
      }
    }
    parts.add(fullBoundary);
    parts.add(finalBoundary);
    return MultipartFormData(
      ContentType('multipart', 'form-data', parameters: <String, String>{
        'boundary': boundary,
      }),
      parts,
    );
  }

  static const List<int> _alphabet = <int>[
    0x0030, 0x0031, 0x0032, 0x0033, 0x0034, 0x0035, 0x0036, 0x0037,
    0x0038, 0x0039, // 0-9
    0x0061, 0x0062, 0x0063, 0x0064, 0x0065, 0x0066, 0x0067, 0x0068,
    0x0069, 0x006a, 0x006b, 0x006c, 0x006d, 0x006e, 0x006f, 0x0070,
    0x0071, 0x0072, 0x0073, 0x0074, 0x0075, 0x0076, 0x0077, 0x0078,
    0x0079, 0x007a, // a-z
    0x0041, 0x0042, 0x0043, 0x0044, 0x0045, 0x0046, 0x0047, 0x0048,
    0x0049, 0x004a, 0x004b, 0x004c, 0x004d, 0x004e, 0x004f, 0x0050,
    0x0051, 0x0052, 0x0053, 0x0054, 0x0055, 0x0056, 0x0057, 0x0058,
    0x0059, 0x005a, // A-Z
  ];

  String _generateBoundary(int length, math.Random random) {
    final StringBuffer result = StringBuffer();
    for (int index = 0; index < length; index += 1)
      result.writeCharCode(_alphabet[random.nextInt(_alphabet.length)]);
    return result.toString();
  }
}

class MultipartFormData {
  const MultipartFormData(this.contentType, this.body);
  final ContentType contentType;
  final List<Uint8List> body;
}
