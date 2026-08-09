import 'package:flutter_test/flutter_test.dart';
import 'package:kiddytube/catalog/youtube_api_defaults.dart';

void main() {
  test('effective prefers parent key over bundled', () {
    expect(
      YoutubeApiDefaults.effective('  AIzaParent  '),
      'AIzaParent',
    );
  });

  test('effective returns null when storage and dart-define are empty', () {
    // Tests run without --dart-define, so bundled default is empty.
    expect(YoutubeApiDefaults.effective(null), isNull);
    expect(YoutubeApiDefaults.effective(''), isNull);
    expect(YoutubeApiDefaults.effective('   '), isNull);
  });
}
