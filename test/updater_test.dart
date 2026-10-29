import 'package:flutter_test/flutter_test.dart';
import 'package:surco/updater.dart';

void main() {
  test('compara versiones número por número', () {
    expect(isNewer('1.2.10', '1.2.9'), isTrue);
    expect(isNewer('v1.3.0', '1.2.1'), isTrue);
    expect(isNewer('1.2.1', '1.2.1'), isFalse);
    expect(isNewer('1.2.0', '1.2.1'), isFalse);
    expect(isNewer('2.0', '1.9.9'), isTrue);
  });
}
