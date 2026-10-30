import 'package:flutter_test/flutter_test.dart';
import 'package:ration_planner/ui/format.dart';

void main() {
  test('fmt: запятая, без «−0»', () {
    expect(fmt(3164.7), '3165');
    expect(fmt(1.26, 1), '1,3');
    expect(fmt(-0.3), '0');
    expect(fmt(-0.04, 1), '0,0');
    expect(fmt(-1.6), '-2');
  });

  test('parseNum: запятая и точка', () {
    expect(parseNum('1,5'), 1.5);
    expect(parseNum(' 102 '), 102);
    expect(parseNum('+10'), 10);
    expect(parseNum('abc'), isNull);
  });
}
