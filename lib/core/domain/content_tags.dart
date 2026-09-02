/// Shared tag vocabulary for anything a user categorizes — routes (via the
/// publish flow's tag picker) and articles. One word list so a reader
/// doesn't have to learn a second vocabulary for blog content.
const routeTags = [
  'Природа',
  'Пешком',
  'С детьми',
  'Водопады',
  'Романтика',
  'Смотровые площадки',
  'Леса',
  'Море',
  'История',
  'Гастрономия',
];

/// Tags that only make sense for a written article, not a route.
const articleOnlyTags = [
  'Личный опыт',
  'Лайфхаки',
  'Бюджетно',
  'Список мест',
  'Один день',
  'Мнение',
];

const articleTags = [...routeTags, ...articleOnlyTags];
