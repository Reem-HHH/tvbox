package ae.kiddytube.app.catalog

/**
 * Family-safe title gate for Muslim households.
 * Drops sync items whose titles mention Halloween, Thanksgiving, Pride/LGBTQ, etc.
 */
object ContentTitleFilter {
    private val blockedKeywords = listOf(
        "halloween",
        "hallowe'en",
        "thanksgiving",
        "lgbt",
        "lgbtq",
        "lgbtq+",
        "lgbtqia",
        "transgender",
        "non-binary",
        "nonbinary",
        "pride month",
        "pride parade",
        "gay pride",
        "drag queen",
        "drag story",
        "هالوين",
        "الهالوين",
        "عيد الشكر",
        "فخر المثلي",
        "مثليون",
        "مثلية",
    )

    private val prideContext =
        Regex("""(^|[^a-z])pride([^a-z]|$)""", RegexOption.IGNORE_CASE)

    fun isAllowed(title: String?): Boolean {
        if (title.isNullOrBlank()) return true
        val normalized = title.lowercase()
        for (keyword in blockedKeywords) {
            if (normalized.contains(keyword.lowercase())) return false
        }
        if (prideContext.containsMatchIn(normalized) &&
            (normalized.contains("month") ||
                normalized.contains("parade") ||
                normalized.contains("flag") ||
                normalized.contains("lgbt") ||
                normalized.contains("202"))
        ) {
            return false
        }
        return true
    }

    fun isBlocked(title: String?): Boolean = !isAllowed(title)
}
