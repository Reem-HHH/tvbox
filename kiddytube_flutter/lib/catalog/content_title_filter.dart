/// Family-safe title gate for Muslim households.
///
/// Drops playlist/sync items whose titles mention Halloween, Thanksgiving,
/// Christmas, Pride/LGBTQ themes, etc. Does not inspect video visuals.
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
    'north pole',
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
    // Arabic spellings / common transliterations
    'هالوين',
    'الهالوين',
    'عيد الشكر',
    'عيد الميلاد',
    'كريسماس',
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
    return true;
  }

  static bool isBlocked(String? title) => !isAllowed(title);
}
