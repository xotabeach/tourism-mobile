/// A versioned help article bundled with this build for offline reading.
class SupportFaqItem {
  const SupportFaqItem({
    required this.id,
    required this.articleId,
    required this.revision,
    required this.title,
    required this.subtitle,
    required this.answer,
  });

  /// Existing FAQ navigation ID; kept stable for bookmarks and deep links.
  final String id;
  final String articleId;
  final int revision;
  final String title;
  final String subtitle;
  final String answer;
}
