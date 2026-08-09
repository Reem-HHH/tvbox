import 'package:flutter_test/flutter_test.dart';
import 'package:kiddytube/catalog/content_title_filter.dart';

void main() {
  test('allows normal kids titles', () {
    expect(ContentTitleFilter.isAllowed('Peppa Pig Muddy Puddles'), isTrue);
    expect(ContentTitleFilter.isAllowed('سورة الفاتحة للأطفال'), isTrue);
    expect(ContentTitleFilter.isAllowed(null), isTrue);
  });

  test('blocks Halloween Thanksgiving LGBTQ titles', () {
    expect(ContentTitleFilter.isBlocked('Halloween Songs for Kids'), isTrue);
    expect(ContentTitleFilter.isBlocked('Happy Thanksgiving Nursery Rhymes'), isTrue);
    expect(ContentTitleFilter.isBlocked('Pride Month Parade for Kids'), isTrue);
    expect(ContentTitleFilter.isBlocked('LGBTQ Story Time'), isTrue);
    expect(ContentTitleFilter.isBlocked('أغاني هالوين للأطفال'), isTrue);
    expect(ContentTitleFilter.isBlocked('عيد الشكر مع الأصدقاء'), isTrue);
  });
}
