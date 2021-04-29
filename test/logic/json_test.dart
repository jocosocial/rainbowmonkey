import 'package:cruisemonkey/src/json.dart';

import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Json', (WidgetTester tester) async {
    final Json a = Json.parse('1');
    expect(a == 1, isTrue); // ignore: unrelated_type_equality_checks
    expect(a != 0, isTrue); // ignore: unrelated_type_equality_checks
    expect(a == '1', isFalse); // ignore: unrelated_type_equality_checks
    expect(a == true, isFalse); // ignore: unrelated_type_equality_checks
    expect(a == false, isFalse); // ignore: unrelated_type_equality_checks
    expect(a.toList(), <dynamic>[1.0]);
    expect(a.toMap(), <String, dynamic>{'0': 1.0});
    expect(a.valueType, double);
    expect(a.toDouble(), 1.0);
    expect(a.toInt(), 1);
    expect(a.toString(), '1.0');
    expect(a.toJson(), '1.0');

    final Json b = Json.parse('0');
    expect(b == 1, isFalse); // ignore: unrelated_type_equality_checks
    expect(b != 0, isFalse); // ignore: unrelated_type_equality_checks
    expect(b == '1', isFalse); // ignore: unrelated_type_equality_checks
    expect(b == true, isFalse); // ignore: unrelated_type_equality_checks
    expect(b == false, isFalse); // ignore: unrelated_type_equality_checks
    expect(b.toList(), <dynamic>[0.0]);
    expect(b.toMap(), <String, dynamic>{'0': 0.0});
    expect(b.valueType, double);
    expect(b.toDouble(), 0.0);
    expect(b.toInt(), 0);
    expect(b.toString(), '0.0');
    expect(b.toJson(), '0.0');

    final Json c = Json.parse('"1"');
    expect(c == 1, isFalse); // ignore: unrelated_type_equality_checks
    expect(c != 0, isTrue); // ignore: unrelated_type_equality_checks
    expect(c == '1', isTrue); // ignore: unrelated_type_equality_checks
    expect(c == true, isFalse); // ignore: unrelated_type_equality_checks
    expect(c == false, isFalse); // ignore: unrelated_type_equality_checks
    expect(c.toList(), <dynamic>['1']);
    expect(c.toMap(), <String, dynamic>{'0': '1'});
    expect(c.valueType, String);
    expect(c.toString(), '1');
    expect(c.toJson(), '"1"');

    final Json d = Json.parse('true');
    expect(d == 1, isFalse); // ignore: unrelated_type_equality_checks
    expect(d != 0, isTrue); // ignore: unrelated_type_equality_checks
    expect(d == '1', isFalse); // ignore: unrelated_type_equality_checks
    expect(d == true, isTrue); // ignore: unrelated_type_equality_checks
    expect(d == false, isFalse); // ignore: unrelated_type_equality_checks
    expect(d.toList(), <dynamic>[true]);
    expect(d.toMap(), <String, dynamic>{'0': true});
    expect(d.valueType, bool);
    expect(d.toBoolean(), true);
    expect(d.toString(), 'true');
    expect(d.toJson(), 'true');

    final Json e = Json.parse('false');
    expect(e == 1, isFalse); // ignore: unrelated_type_equality_checks
    expect(e != 0, isTrue); // ignore: unrelated_type_equality_checks
    expect(e == '1', isFalse); // ignore: unrelated_type_equality_checks
    expect(e == true, isFalse); // ignore: unrelated_type_equality_checks
    expect(e == false, isTrue); // ignore: unrelated_type_equality_checks
    expect(e.toList(), <dynamic>[false]);
    expect(e.toMap(), <String, dynamic>{'0': false});
    expect(e.valueType, bool);
    expect(e.toBoolean(), false);
    expect(e.toString(), 'false');
    expect(e.toJson(), 'false');

    final Json f = Json.parse('[1, 2]');
    expect(f == 1, isFalse); // ignore: unrelated_type_equality_checks
    expect(f != 0, isTrue); // ignore: unrelated_type_equality_checks
    expect(f == '1', isFalse); // ignore: unrelated_type_equality_checks
    expect(f == true, isFalse); // ignore: unrelated_type_equality_checks
    expect(f == false, isFalse); // ignore: unrelated_type_equality_checks
    expect(f[0] == 1, isTrue); // ignore: unrelated_type_equality_checks
    expect(f[1] == 2, isTrue); // ignore: unrelated_type_equality_checks
    expect(f[0] == 0, isFalse); // ignore: unrelated_type_equality_checks
    expect(f[1] == 0, isFalse); // ignore: unrelated_type_equality_checks
    expect(f.asIterable().length == 2, isTrue);
    expect(f.asIterable(), <Json>[Json(1), Json(2)]);
    expect(f.toList(), <double>[1, 2]);
    expect(f.toMap(), <String, dynamic>{'0': 1.0, '1': 2.0});
    expect(f.valueType, <Json>[].runtimeType);
    expect(f.toJson(), '[1.0,2.0]');

    final Json g = Json.parse('{"1": "a", "2": "b"}');
    expect(g == 1, isFalse); // ignore: unrelated_type_equality_checks
    expect(g != 0, isTrue); // ignore: unrelated_type_equality_checks
    expect(g == '1', isFalse); // ignore: unrelated_type_equality_checks
    expect(g == true, isFalse); // ignore: unrelated_type_equality_checks
    expect(g == false, isFalse); // ignore: unrelated_type_equality_checks
    expect(g[0] == 'a', isFalse); // ignore: unrelated_type_equality_checks
    expect(g[1] == 'b', isFalse); // ignore: unrelated_type_equality_checks
    expect(g['1'] == 'a', isTrue); // ignore: unrelated_type_equality_checks
    expect(g['2'] == 'b', isTrue); // ignore: unrelated_type_equality_checks
    expect(g['0'] == null, isTrue); // ignore: unrelated_type_equality_checks
    expect(g['1'] == 0, isFalse); // ignore: unrelated_type_equality_checks
    expect(g['2'] == 0, isFalse); // ignore: unrelated_type_equality_checks
    expect(g.asIterable().length == 2, isTrue);
    expect(g.asIterable(), <Json>[Json('a'), Json('b')]);
    expect(g.toMap(), <String, dynamic>{'1': 'a', '2': 'b'});
    expect(g.toList(), <dynamic>['a', 'b']);
    expect(g.valueType, <String, Json>{}.runtimeType);
    expect(g.toJson(), '{"1":"a","2":"b"}');

    final Json h = Json(g);
    expect(h == 1, isFalse); // ignore: unrelated_type_equality_checks
    expect(h != 0, isTrue); // ignore: unrelated_type_equality_checks
    expect(h == '1', isFalse); // ignore: unrelated_type_equality_checks
    expect(h == true, isFalse); // ignore: unrelated_type_equality_checks
    expect(h == false, isFalse); // ignore: unrelated_type_equality_checks
    expect(h[0] == 'a', isFalse); // ignore: unrelated_type_equality_checks
    expect(h[1] == 'b', isFalse); // ignore: unrelated_type_equality_checks
    expect(h['1'] == 'a', isTrue); // ignore: unrelated_type_equality_checks
    expect(h['2'] == 'b', isTrue); // ignore: unrelated_type_equality_checks
    expect(h['0'] == null, isTrue); // ignore: unrelated_type_equality_checks
    expect(h['1'] == 0, isFalse); // ignore: unrelated_type_equality_checks
    expect(h['2'] == 0, isFalse); // ignore: unrelated_type_equality_checks
    expect(h.asIterable().length == 2, isTrue);
    expect(h.asIterable(), <Json>[Json('a'), Json('b')]);
    expect(h.toMap(), <String, dynamic>{'1': 'a', '2': 'b'});
    expect(h.toList(), <dynamic>['a', 'b']);
    expect(h.valueType, g.valueType);
    expect(h.toJson(), '{"1":"a","2":"b"}');

    final Json i = Json.map(const <String, String>{'1': 'a', '2': 'b'});
    expect(i == 1, isFalse); // ignore: unrelated_type_equality_checks
    expect(i != 0, isTrue); // ignore: unrelated_type_equality_checks
    expect(i == '1', isFalse); // ignore: unrelated_type_equality_checks
    expect(i == true, isFalse); // ignore: unrelated_type_equality_checks
    expect(i == false, isFalse); // ignore: unrelated_type_equality_checks
    expect(i[0] == 'a', isFalse); // ignore: unrelated_type_equality_checks
    expect(i[1] == 'b', isFalse); // ignore: unrelated_type_equality_checks
    expect(i['1'] == 'a', isTrue); // ignore: unrelated_type_equality_checks
    expect(i['2'] == 'b', isTrue); // ignore: unrelated_type_equality_checks
    expect(i['0'] == null, isTrue); // ignore: unrelated_type_equality_checks
    expect(i['1'] == 0, isFalse); // ignore: unrelated_type_equality_checks
    expect(i['2'] == 0, isFalse); // ignore: unrelated_type_equality_checks
    expect(i.asIterable().length == 2, isTrue);
    expect(i.asIterable(), <Json>[Json('a'), Json('b')]);
    expect(i.toMap(), <String, dynamic>{'1': 'a', '2': 'b'});
    expect(i.toList(), <dynamic>['a', 'b']);
    expect(i.valueType, g.valueType);
    expect(i.toJson(), '{"1":"a","2":"b"}');

    g['foo'] = 10;
    h['bar'] = 11;
    i['qux'] = 12;
    expect(g.toMap(), <String, dynamic>{'1': 'a', '2': 'b', 'foo': 10.0});
    expect(h.toMap(), <String, dynamic>{'1': 'a', '2': 'b', 'bar': 11.0});
    expect(i.toMap(), <String, dynamic>{'1': 'a', '2': 'b', 'qux': 12.0});
    expect((g as dynamic).foo, Json(10));
    expect((h as dynamic).bar, Json(11));
    expect((i as dynamic).qux, Json(12));
    (g as dynamic).foo = 98;
    (g as dynamic).doo = 99;
    expect(g.toMap(), <String, dynamic>{'1': 'a', '2': 'b', 'foo': 98.0, 'doo': 99.0});

    final Json j = Json.list(<int>[1, 2]);
    expect(j == 1, isFalse); // ignore: unrelated_type_equality_checks
    expect(j != 0, isTrue); // ignore: unrelated_type_equality_checks
    expect(j == '1', isFalse); // ignore: unrelated_type_equality_checks
    expect(j == true, isFalse); // ignore: unrelated_type_equality_checks
    expect(j == false, isFalse); // ignore: unrelated_type_equality_checks
    expect(j[0] == 1, isTrue); // ignore: unrelated_type_equality_checks
    expect(j[1] == 2, isTrue); // ignore: unrelated_type_equality_checks
    expect(j[0] == 0, isFalse); // ignore: unrelated_type_equality_checks
    expect(j[1] == 0, isFalse); // ignore: unrelated_type_equality_checks
    expect(j.asIterable().length == 2, isTrue);
    expect(j.asIterable(), <Json>[Json(1), Json(2)]);
    expect(j.toList(), <int>[1, 2]);
    expect(j.toMap(), <String, dynamic>{'0': 1.0, '1': 2.0});
    expect(j.valueType, f.valueType);
    expect(j.toJson(), '[1.0,2.0]');

    j[1] = 3;
    expect(j[1] == 3, isTrue); // ignore: unrelated_type_equality_checks
    expect(j.asIterable(), <Json>[Json(1), Json(3)]);
    expect(j.toList(), <int>[1, 3]);
    expect(j.toMap(), <String, dynamic>{'0': 1.0, '1': 3.0});
    expect(j.toJson(), '[1.0,3.0]');

    expect(Json(2) < Json(3), isTrue);
    expect(Json(2) > Json(3), isFalse);
    expect(Json(2) <= Json(3), isTrue);
    expect(Json(2) >= Json(3), isFalse);
    expect(Json(5) < Json(5), isFalse);
    expect(Json(5) > Json(5), isFalse);
    expect(Json(5) <= Json(5), isTrue);
    expect(Json(5) >= Json(5), isTrue);

    expect(Json(2) < 3, isTrue);
    expect(Json(2) > 3, isFalse);
    expect(Json(2) <= 3, isTrue);
    expect(Json(2) >= 3, isFalse);
    expect(Json(5) < 5, isFalse);
    expect(Json(5) > 5, isFalse);
    expect(Json(5) <= 5, isTrue);
    expect(Json(5) >= 5, isTrue);

    expect(Json(6) + Json(3), 9);
    expect(Json(6) - Json(3), 3);
    expect(Json(6) / Json(3), 2);
    expect(Json(6) ~/ Json(3), 2);
    expect(Json(6) % Json(3), 0);
    expect(Json(6) * Json(3), 18);
    expect(Json(6) | Json(3), 7);
    expect(Json(6) & Json(3), 2);
    expect(Json(6) ^ Json(3), 5);
    expect(Json(6) << Json(3), 48);
    expect(Json(6) >> Json(3), 0);

    expect(Json(6) + 3, 9);
    expect(Json(6) - 3, 3);
    expect(Json(6) / 3, 2);
    expect(Json(6) ~/ 3, 2);
    expect(Json(6) % 3, 0);
    expect(Json(6) * 3, 18);
    expect(Json(6) | 3, 7);
    expect(Json(6) & 3, 2);
    expect(Json(6) ^ 3, 5);
    expect(Json(6) << 3, 48);
    expect(Json(6) >> 3, 0);

    expect(Json(false).hashCode == Json(false).hashCode, isTrue);
    expect(Json(false).hashCode != Json(true).hashCode, isTrue);
    expect(Json(false).hashCode != Json(0).hashCode, isTrue);
    expect(Json(0).hashCode == Json(0).hashCode, isTrue);
    expect(Json(0).hashCode != Json(1).hashCode, isTrue);
    expect(Json(1).hashCode == Json(1).hashCode, isTrue);
    expect(Json(1.0).hashCode == Json(1).hashCode, isTrue);
    expect(Json(1.0).hashCode == Json(1.0).hashCode, isTrue);
    expect(Json('1.0').hashCode != Json(1.0).hashCode, isTrue);
  });
}
