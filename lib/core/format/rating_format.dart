/// Formatting for route ratings.
///
/// Kept apart from the widgets because the card, the details header and the
/// reviews section all have to say the same number the same way — the card
/// used to invent one from the route's name, which is exactly the kind of
/// drift a shared formatter prevents.
library;

/// `4.5` → `4,5`. Comma, one decimal, as Russian typography expects.
String formatRatingAverage(double? average) {
  if (average == null) {
    return '';
  }
  return average.toStringAsFixed(1).replaceAll('.', ',');
}

/// `4,3 (12)` — the average with how many people gave it.
String formatRatingWithCount(double? average, int count) {
  if (average == null || count <= 0) {
    return '';
  }
  return '${formatRatingAverage(average)} ($count)';
}

/// "12 оценок" — for the semantic label, where a bare number reads badly.
String ratingCountLabel(int count) {
  final lastTwo = count % 100;
  final last = count % 10;
  if (lastTwo >= 11 && lastTwo <= 14) {
    return '$count оценок';
  }
  return switch (last) {
    1 => '$count оценка',
    2 || 3 || 4 => '$count оценки',
    _ => '$count оценок',
  };
}
