/// Shared tag vocabulary for anything a user categorizes — routes (via the
/// publish flow's tag picker) and articles. One word list so a reader
/// doesn't have to learn a second vocabulary for blog content.
const _sharedTags = [
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

/// «Море» is not the author's pick for a route: the server works it out
/// from the stops (BACKEND-19).
final routeTags = [
  for (final tag in _sharedTags)
    if (tag != 'Море') tag,
  // Drives the route, with walks to what a car cannot reach (spec 14b).
  carRouteTag,
];

/// The tag that makes an author's route a drive; the server reads it too.
const carRouteTag = 'На машине';

const articleTags = [..._sharedTags, ...articleOnlyTags];
