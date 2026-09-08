import 'package:flutter_test/flutter_test.dart';
import 'package:kiddytube/catalog/content_title_filter.dart';

void main() {
  test('allows normal kids titles', () {
    expect(ContentTitleFilter.isAllowed('Peppa Pig Muddy Puddles'), isTrue);
    expect(ContentTitleFilter.isAllowed('سورة الفاتحة للأطفال'), isTrue);
    expect(ContentTitleFilter.isAllowed(null), isTrue);
  });

  test('blocks Halloween Thanksgiving Christmas LGBTQ titles', () {
    expect(ContentTitleFilter.isBlocked('Halloween Songs for Kids'), isTrue);
    expect(ContentTitleFilter.isBlocked('Happy Thanksgiving Nursery Rhymes'), isTrue);
    expect(ContentTitleFilter.isBlocked('Ben & Holly Christmas Special'), isTrue);
    expect(ContentTitleFilter.isBlocked('Merry Xmas Nursery Rhymes'), isTrue);
    expect(ContentTitleFilter.isBlocked('Santa Claus Songs for Kids'), isTrue);
    expect(ContentTitleFilter.isBlocked('Let\'s Spell SANTA'), isTrue);
    expect(ContentTitleFilter.isBlocked('The North Pole! — Full Episode'), isTrue);
    expect(ContentTitleFilter.isBlocked('Easter Bunny Songs'), isTrue);
    expect(ContentTitleFilter.isBlocked('Jesus Loves Me for Kids'), isTrue);
    expect(ContentTitleFilter.isBlocked('Pride Month Parade for Kids'), isTrue);
    expect(ContentTitleFilter.isBlocked('LGBTQ Story Time'), isTrue);
    expect(ContentTitleFilter.isBlocked('Spooky Ghost Night for Kids'), isTrue);
    expect(ContentTitleFilter.isBlocked('Haunted House Song'), isTrue);
    expect(ContentTitleFilter.isBlocked('Zombie Dance for Kids'), isTrue);
    expect(ContentTitleFilter.isBlocked('Horror Story Time'), isTrue);
    expect(ContentTitleFilter.isBlocked('Scary shadows! Halloween Colour Fun'), isTrue);
    expect(ContentTitleFilter.isBlocked('Presents 🎁 | NEW EPISODE | Bing Full Episodes'), isTrue);
    expect(ContentTitleFilter.isBlocked('@officialalphablocks - Boo! 👻 | New Special!'), isTrue);
    expect(ContentTitleFilter.isBlocked('أغاني هالوين للأطفال'), isTrue);
    expect(ContentTitleFilter.isBlocked('عيد الشكر مع الأصدقاء'), isTrue);
    expect(ContentTitleFilter.isBlocked('أغاني عيد الميلاد'), isTrue);
    expect(ContentTitleFilter.isBlocked('أناشيد عن يسوع للأطفال'), isTrue);
  });

  test('allows non-holiday Bing and birthday present titles', () {
    expect(ContentTitleFilter.isAllowed('Fossil | Bing Full Episode'), isTrue);
    expect(ContentTitleFilter.isAllowed('Peppa Pig Birthday Present'), isTrue);
  });

  test('blocks clean titles when YouTube tags are off-brief', () {
    expect(
      ContentTitleFilter.isBlocked(
        'Peppa Pig Muddy Puddles',
        tags: ['kids', 'halloween'],
      ),
      isTrue,
    );
    expect(
      ContentTitleFilter.isBlocked(
        'Colour Fun',
        tags: ['christmas'],
      ),
      isTrue,
    );
    expect(
      ContentTitleFilter.isBlocked(
        'Story Time',
        tags: ['lgbt'],
      ),
      isTrue,
    );
    expect(
      ContentTitleFilter.isBlocked(
        'أغنية جديدة',
        tags: ['عيد الميلاد'],
      ),
      isTrue,
    );
    expect(
      ContentTitleFilter.isBlocked(
        'Fossil | Bing Full Episode',
        tags: ['pride'],
      ),
      isTrue,
    );
  });

  test('allows clean titles with empty or benign tags', () {
    expect(
      ContentTitleFilter.isAllowed(
        'Peppa Pig Muddy Puddles',
        tags: ['kids', 'peppa'],
      ),
      isTrue,
    );
    expect(
      ContentTitleFilter.isAllowed('Peppa Pig Birthday Present', tags: const []),
      isTrue,
    );
    expect(ContentTitleFilter.isAllowed('Peppa Pig Birthday Present'), isTrue);
    expect(
      ContentTitleFilter.isAllowed('Fossil | Bing Full Episode', tags: ['bing']),
      isTrue,
    );
  });
}
