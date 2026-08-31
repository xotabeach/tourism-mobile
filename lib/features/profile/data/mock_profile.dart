import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/features/profile/domain/profile.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';

abstract final class MockProfile {
  static const rank = ProfileRank(
    title: 'Продвинутый пешеход',
    progressPoints: 12500,
    nextRankPoints: 25000,
    leaderboardPlace: 1345,
  );

  static const achievementPages = <List<ProfileAchievement>>[
    [
      ProfileAchievement(
        id: 'ach-marathoner',
        title: 'Марафонец',
        description: 'Пройти суммарно 48 км за неделю',
      ),
      ProfileAchievement(
        id: 'ach-same-way',
        title: 'Ты норм?',
        description: 'Вернуться по тому же маршруту',
      ),
      ProfileAchievement(
        id: 'ach-berlin',
        title: 'Ура Советам',
        description: 'Дойти пешком до Берлина',
        isUnlocked: false,
      ),
    ],
    [
      ProfileAchievement(
        id: 'ach-sunrise',
        title: 'Ранняя пташка',
        description: 'Встретить рассвет на маршруте',
      ),
      ProfileAchievement(
        id: 'ach-water',
        title: 'К воде',
        description: 'Пройти 3 приморских маршрута',
      ),
      ProfileAchievement(
        id: 'ach-caves',
        title: 'Подземный гость',
        description: 'Посетить пещерный город',
        isUnlocked: false,
      ),
    ],
    [
      ProfileAchievement(
        id: 'ach-photo',
        title: 'Кадр дня',
        description: 'Добавить 10 фото к остановкам',
      ),
      ProfileAchievement(
        id: 'ach-night',
        title: 'Ночной дозор',
        description: 'Завершить маршрут после заката',
      ),
      ProfileAchievement(
        id: 'ach-group',
        title: 'Компания',
        description: 'Пройти маршрут с друзьями',
        isUnlocked: false,
      ),
    ],
    [
      ProfileAchievement(
        id: 'ach-season',
        title: 'Все сезоны',
        description: 'Пройти маршруты зимой и летом',
      ),
      ProfileAchievement(
        id: 'ach-local',
        title: 'Местный',
        description: 'Отметить 20 мест Крыма',
      ),
      ProfileAchievement(
        id: 'ach-guide',
        title: 'Свой гид',
        description: 'Прослушать 5 аудиогидов',
        isUnlocked: false,
      ),
    ],
    [
      ProfileAchievement(
        id: 'ach-distance',
        title: 'Сто км',
        description: 'Набрать 100 км суммарно',
      ),
      ProfileAchievement(
        id: 'ach-favorite',
        title: 'Коллекционер',
        description: 'Сохранить 15 маршрутов',
      ),
      ProfileAchievement(
        id: 'ach-review',
        title: 'Отзывчивый',
        description: 'Оставить 5 отзывов',
        isUnlocked: false,
      ),
    ],
  ];

  static const publishedRoutes = <RouteSummary>[
    RouteSummary(
      id: 'route-chok-sary-kaya',
      name: 'Гора Чок-Сары-Кая',
      slug: 'chok-sary-kaya',
      shortDescription: 'Тропа к смотровой над Бахчисараем.',
      stopsCount: 4,
      estimatedDurationMinutes: 210,
      distanceMeters: 8600,
      difficulty: 'moderate',
      transportMode: 'walk',
      isRoundTrip: true,
      authorLabel: 'Никита',
      coverImageUrl: AppImages.coastPineTwilight,
    ),
    RouteSummary(
      id: 'route-bakhchisaray',
      name: 'Наследие Бахчисарая',
      slug: 'bakhchisaray-heritage',
      shortDescription: 'Ханский дворец и пещерный город Чуфут-Кале.',
      stopsCount: 2,
      estimatedDurationMinutes: 300,
      distanceMeters: 12000,
      difficulty: 'moderate',
      transportMode: 'car',
      isRoundTrip: true,
      authorLabel: 'Никита',
      coverImageUrl: AppImages.coastalBayHills,
    ),
    RouteSummary(
      id: 'route-coast-trail',
      name: 'Море и сосны: Фиолент — Новый Свет',
      slug: 'coast-pine-trail',
      shortDescription: 'Скалистый берег, лесные тропы и бухты у моря.',
      stopsCount: 3,
      estimatedDurationMinutes: 420,
      distanceMeters: 18000,
      difficulty: 'hard',
      transportMode: 'walk',
      isRoundTrip: false,
      authorLabel: 'Никита',
      coverImageUrl: AppImages.capeFiolentFog,
    ),
    RouteSummary(
      id: 'route-south-coast',
      name: 'Классика Южного берега',
      slug: 'south-coast-classics',
      shortDescription: 'Дворцы и символ Крыма за один день у Ялты.',
      stopsCount: 3,
      estimatedDurationMinutes: 360,
      distanceMeters: 28000,
      difficulty: 'easy',
      transportMode: 'car',
      isRoundTrip: true,
      authorLabel: 'Никита',
      coverImageUrl: AppImages.welcomeSunset,
    ),
    RouteSummary(
      id: 'route-ai-petri-ridge',
      name: 'Хребет Ай-Петри',
      slug: 'ai-petri-ridge',
      shortDescription: 'Подъём к зубцам и панорама ЮБК.',
      stopsCount: 3,
      estimatedDurationMinutes: 270,
      distanceMeters: 9800,
      difficulty: 'hard',
      transportMode: 'walk',
      isRoundTrip: true,
      authorLabel: 'Никита',
      coverImageUrl: AppImages.coastPineTwilight,
    ),
  ];

  static ProfileSnapshot snapshot({
    String? displayName,
    String? avatarImageUrl,
    String? coverImageUrl,
  }) {
    final name = (displayName?.trim().isNotEmpty ?? false)
        ? displayName!.trim()
        : 'Никита Можаров';
    return ProfileSnapshot(
      displayName: name,
      rank: rank,
      coverImageAsset: AppImages.welcomeSunset,
      avatarImageAsset: AppImages.travelerPortrait,
      avatarImageUrl: avatarImageUrl,
      coverImageUrl: coverImageUrl,
      achievementPages: achievementPages,
      publishedRoutes: [
        for (final route in publishedRoutes)
          RouteSummary(
            id: route.id,
            name: route.name,
            slug: route.slug,
            shortDescription: route.shortDescription,
            stopsCount: route.stopsCount,
            estimatedDurationMinutes: route.estimatedDurationMinutes,
            distanceMeters: route.distanceMeters,
            difficulty: route.difficulty,
            transportMode: route.transportMode,
            isRoundTrip: route.isRoundTrip,
            authorLabel: name.split(RegExp(r'\s+')).first,
            coverImageUrl: route.coverImageUrl,
          ),
      ],
      completedRoutesCount: 7,
      reviewsWrittenCount: 3,
      totalDistanceMeters: 142500,
    );
  }
}
