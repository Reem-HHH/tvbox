/// Family-safe title gate for Muslim households.
///
/// Drops playlist/sync items whose titles mention Halloween, Thanksgiving,
/// Christmas, Christian/other religious propaganda, Pride/LGBTQ themes,
/// or common scary/spooky Halloween wording. Does not inspect video visuals
/// or YouTube tags.
class ContentTitleFilter {
  ContentTitleFilter._();

  static const blockedKeywords = <String>[
    'halloween',
    'hallowe\'en',
    'thanksgiving',
    'christmas',
    'xmas',
    'father christmas',
    'santa claus',
    'santa',
    'north pole',
    'easter',
    'jesus',
    'gospel',
    'bible study',
    'sunday school',
    'christian',
    'church service',
    'lgbt',
    'lgbtq',
    'lgbtq+',
    'lgbtqia',
    'transgender',
    'non-binary',
    'nonbinary',
    'pride month',
    'pride parade',
    'gay pride',
    'drag queen',
    'drag story',
    // Scary / spooky holiday wording
    'spooky',
    'haunted',
    'scary',
    'nightmare',
    'trick-or-treat',
    'trick or treat',
    'jack-o-lantern',
    'jack-a-lantern',
    'jack o lantern',
    'letters to santa',
    // Arabic spellings / common transliterations
    'هالوين',
    'الهالوين',
    'عيد الشكر',
    'عيد الميلاد',
    'كريسماس',
    'عيد الفصح',
    'يسوع',
    'المسيح',
    'كنيسة',
    'الإنجيل',
    'انجيل',
    'فخر المثلي',
    'مثليون',
    'مثلية',
  ];

  /// Returns true when [title] should be kept for kids playback.
  static bool isAllowed(String? title) {
    if (title == null || title.trim().isEmpty) return true;
    final normalized = title.toLowerCase();
    for (final keyword in blockedKeywords) {
      if (normalized.contains(keyword.toLowerCase())) {
        return false;
      }
    }
    // Whole-word-ish "pride" to avoid blocking "pride and joy" less often —
    // still block common Pride festival phrasing via keywords above; also
    // catch " pride " / "#pride".
    if (RegExp(r'(^|[^a-z])pride([^a-z]|$)').hasMatch(normalized) &&
        (normalized.contains('month') ||
            normalized.contains('parade') ||
            normalized.contains('flag') ||
            normalized.contains('lgbt') ||
            normalized.contains('202'))) {
      return false;
    }
    // Soft Christmas titles (e.g. Bing "Presents 🎁" without saying Christmas).
    if (RegExp(r'(^|[^a-z])presents([^a-z]|$)').hasMatch(normalized) &&
        normalized.contains('bing')) {
      return false;
    }
    // Halloween "Boo!" specials that omit the word Halloween.
    if (normalized.contains('boo!') &&
        (normalized.contains('special') ||
            title.contains('👻') ||
            normalized.contains('halloween'))) {
      return false;
    }
    return true;
  }

  static bool isBlocked(String? title) => !isAllowed(title);
}
