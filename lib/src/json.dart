// Copyright 2017 The Chromium Authors. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are
// met:
//
//    * Redistributions of source code must retain the above copyright
// notice, this list of conditions and the following disclaimer.
//    * Redistributions in binary form must reproduce the above
// copyright notice, this list of conditions and the following disclaimer
// in the documentation and/or other materials provided with the
// distribution.
//    * Neither the name of Google Inc. nor the names of its
// contributors may be used to endorse or promote products derived from
// this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
// LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import 'dart:convert' as dart show JSON;

class Json {
  factory Json(dynamic input) {
    if (input is Json)
      return _wrap(input._value);
    return _wrap(input);
  }

  factory Json.list(List<dynamic> input) {
    return new Json._raw(input.map<Json>(_wrap).toList());
  }

  // (This differs from "real" JSON in that we don't allow duplicate keys.)
  factory Json.map(Map<dynamic, dynamic> input) {
    final Map<String, Json> values = <String, Json>{};
    input.forEach((dynamic key, dynamic value) {
      final String name = key.toString();
      assert(!values.containsKey(name), 'Json.map keys must be unique strings');
      values[name] = _wrap(value);
    });
    return new Json._raw(values);
  }

  const Json._raw(this._value);

  static Json parse(String value) {
    return new Json(dart.JSON.decode(value));
  }

  final dynamic _value;

  static Json _wrap(dynamic value) {
    if (value == null)
      return const Json._raw(null);
    if (value is num)
      return new Json._raw(value.toDouble());
    if (value is List)
      return new Json.list(value);
    if (value is Map)
      return new Json.map(value);
    if (value == true)
      return const Json._raw(true);
    if (value == false)
      return const Json._raw(false);
    if (value is Json)
      return value;
    return new Json._raw(value.toString());
  }

  dynamic _unwrap() {
    if (_value is Map)
      return toMap();
    if (_value is List)
      return toList();
    return _value;
  }

  Type get valueType => (_value as Object).runtimeType;

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> values = <String, dynamic>{};
    if (_value is Map) {
      _value.forEach((String key, Json value) {
        values[key] = value._unwrap();
      });
    } else if (_value is List) {
      for (int index = 0; index < (_value as List<dynamic>).length; index += 1)
        values[index.toString()] = _value[index]._unwrap();
    } else {
      values['0'] = _unwrap();
    }
    return values;
  }

  List<dynamic> toList() {
    if (_value is Map)
      return (_value as Map<String, Json>).values.map<dynamic>((Json value) => value._unwrap()).toList();
    if (_value is List)
      return (_value as List<Json>).map<dynamic>((Json value) => value._unwrap()).toList();
    return <dynamic>[_unwrap()];
  }

  List<dynamic> asIterable() {
    if (_value is Map)
      return (_value as Map<String, Json>).values.toList();
    if (_value is List)
      return (_value as List<Json>);
    return const <Json>[];
  }

  double toDouble() => _value as double;

  int toInt() => (_value as double).toInt();

  bool toBoolean() => _value as bool;

  @override
  String toString() => _value.toString();

  String toJson() {
    return dart.JSON.encode(_unwrap());
  }

  dynamic operator [](dynamic key) {
    return _value[key];
  }

  void operator []=(dynamic key, dynamic value) {
    _value[key] = _wrap(value);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isGetter) {
      final String name = _symbolName(invocation.memberName);
      if (_value is Map && (_value as Map<String, Json>).containsKey(name))
        return this[name];
    }
    if (invocation.isSetter)
      return this[_symbolName(invocation.memberName)] = invocation.positionalArguments[0];
    return super.noSuchMethod(invocation);
  }

  // Workaround for https://github.com/dart-lang/sdk/issues/28372
  String _symbolName(Symbol symbol) {
    // WARNING: Assumes a fixed format for Symbol.toString which is *not*
    // guaranteed anywhere.
    final String s = '$symbol';
    return s.substring(8, s.length - 2);
  }

  bool operator <(dynamic other) {
    if (other.runtimeType != Json)
      return (_value < other) as bool;
    return (_value < other._value) as bool;
  }

  bool operator <=(dynamic other) {
    if (other.runtimeType != Json)
      return (_value <= other) as bool;
    return (_value <= other._value) as bool;
  }

  bool operator >(dynamic other) {
    if (other.runtimeType != Json)
      return (_value > other) as bool;
    return (_value > other._value) as bool;
  }

  bool operator >=(dynamic other) {
    if (other.runtimeType != Json)
      return (_value >= other) as bool;
    return (_value >= other._value) as bool;
  }

  dynamic operator -(dynamic other) {
    if (other.runtimeType != Json)
      return _value - other;
    return _value - other._value;
  }

  dynamic operator +(dynamic other) {
    if (other.runtimeType != Json)
      return _value + other;
    return _value + other._value;
  }

  dynamic operator /(dynamic other) {
    if (other.runtimeType != Json)
      return _value / other;
    return _value / other._value;
  }

  dynamic operator ~/(dynamic other) {
    if (other.runtimeType != Json)
      return _value ~/ other;
    return _value ~/ other._value;
  }

  dynamic operator *(dynamic other) {
    if (other.runtimeType != Json)
      return _value * other;
    return _value * other._value;
  }

  dynamic operator %(dynamic other) {
    if (other.runtimeType != Json)
      return _value % other;
    return _value % other._value;
  }

  dynamic operator |(dynamic other) {
    if (other.runtimeType != Json)
      return _value | other;
    return _value | other._value;
  }

  dynamic operator ^(dynamic other) {
    if (other.runtimeType != Json)
      return _value ^ other;
    return _value ^ other._value;
  }

  dynamic operator &(dynamic other) {
    if (other.runtimeType != Json)
      return _value & other;
    return _value & other._value;
  }

  dynamic operator <<(dynamic other) {
    if (other.runtimeType != Json)
      return _value << other;
    return _value << other._value;
  }

  dynamic operator >>(dynamic other) {
    if (other.runtimeType != Json)
      return _value >> other;
    return _value >> other._value;
  }

  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != Json)
      return _value == other;
    return _value == other._value;
  }

  @override
  int get hashCode => _value.hashCode;
}
