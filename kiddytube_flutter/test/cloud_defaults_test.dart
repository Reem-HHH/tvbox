import 'package:flutter_test/flutter_test.dart';
import 'package:kiddytube/cloud/cloud_defaults.dart';

void main() {
  test('canAutoEnroll is false without dart-defines', () {
    // Tests run without CLOUD_* defines.
    expect(CloudDefaults.baseUrl, isNull);
    expect(CloudDefaults.enrollSecret, isNull);
    expect(CloudDefaults.canAutoEnroll, isFalse);
  });
}
