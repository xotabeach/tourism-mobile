import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/core/theme/app_theme.dart';
import 'package:tourism_mobile/features/articles/application/articles_providers.dart';
import 'package:tourism_mobile/features/articles/domain/article.dart';
import 'package:tourism_mobile/features/articles/domain/articles_repository.dart';
import 'package:tourism_mobile/features/articles/presentation/article_details_screen.dart';
import 'package:tourism_mobile/features/articles/presentation/article_editor_screen.dart';
import 'package:tourism_mobile/features/articles/presentation/widgets/article_card.dart';

import '../support/test_overrides.dart';

const _goldenKey = ValueKey('golden-surface');
const _phoneSize = Size(393, 852);

/// Baselines are recorded on macOS, like the rest of the golden suite.
final _skipPixelGoldens =
    !Platform.isMacOS || Platform.environment['SKIP_PIXEL_GOLDENS'] == '1';

ArticleSummary _summary({
  String id = 'article-1',
  String title = 'Три дня на Южном берегу без машины',
  List<String> tags = const ['История', 'Личный опыт'],
  int likeCount = 18,
  bool likedByMe = false,
  ArticleStatus status = ArticleStatus.published,
}) {
  return ArticleSummary(
    id: id,
    title: title,
    status: status,
    authorUserId: 'author-1',
    authorDisplayName: 'Никита Тарасов',
    createdAt: DateTime.utc(2026, 8, 1),
    publishedAt: DateTime.utc(2026, 8, 12),
    coverImageUrl: AppImages.coastPineTwilight,
    tags: tags,
    likeCount: likeCount,
    likedByMe: likedByMe,
    readingTimeMinutes: 4,
    viewCount: 1240,
    authorRankTitle: 'Продвинутый пешеход',
    excerpt: 'Маршрут занял три полных дня, электричек и автобусов было больше.',
  );
}

final _article = Article(
  id: 'article-1',
  title: 'Три дня на Южном берегу без машины',
  status: ArticleStatus.published,
  authorUserId: 'author-1',
  authorDisplayName: 'Никита Тарасов',
  createdAt: DateTime.utc(2026, 8, 1),
  publishedAt: DateTime.utc(2026, 8, 12),
  coverImageUrl: AppImages.coastPineTwilight,
  tags: const ['История', 'Личный опыт'],
  authorRankTitle: 'Продвинутый пешеход',
  readingTimeMinutes: 4,
  likeCount: 128,
  viewCount: 1240,
  relatedRouteId: 'route-1',
  blocks: const [
    ArticleBlock(
      id: 'b1',
      position: 0,
      blockType: ArticleBlockType.text,
      textContent:
          'Маршрут занял три полных дня, электричек и автобусов было больше, '
          'чем ожидалось, но вид с канатки того стоил.',
    ),
    ArticleBlock(
      id: 'b2',
      position: 1,
      blockType: ArticleBlockType.quote,
      textContent:
          'Если ехать без машины — закладывайте на полчаса больше на любой '
          'переход, автобусы в сезон переполнены.',
      caption: 'из разговора с местным гидом',
    ),
    ArticleBlock(
      id: 'b3',
      position: 2,
      blockType: ArticleBlockType.list,
      textContent:
          'Канатная дорога «Мисхор — Ай-Петри» — ехать до 10:00\n'
          'Обед в Мисхоре — кафе у нижней станции\n'
          'Возврат автобусом №5 — последний рейс в 19:40',
      listStyle: ListStyle.bullet,
    ),
    ArticleBlock(
      id: 'b4',
      position: 3,
      blockType: ArticleBlockType.divider,
    ),
    ArticleBlock(
      id: 'b5',
      position: 4,
      blockType: ArticleBlockType.text,
      textContent:
          'В остальном маршрут несложный: набережная, канатка и один переезд '
          'между посёлками.',
    ),
  ],
);

class _GoldenArticlesRepository implements ArticlesRepository {
  @override
  Future<Article> getArticle(String id) async => _article;

  @override
  Future<ArticleCommentPage> listComments(
    String articleId, {
    int limit = 50,
    int offset = 0,
  }) async {
    return ArticleCommentPage(
      items: [
        ArticleComment(
          id: 'c1',
          articleId: articleId,
          authorUserId: 'other',
          authorDisplayName: 'Мария',
          body: 'Отличный маршрут, повторили в июле!',
          status: ArticleCommentStatus.published,
          createdAt: DateTime.utc(2026, 8, 13),
        ),
      ],
      total: 1,
    );
  }

  @override
  Future<ArticleListPage> listRelated(String articleId) async {
    final items = [
      _summary(
        id: 'article-2',
        title: 'Гастротур по набережной Алушты',
        tags: const ['Гастрономия'],
        likeCount: 42,
      ),
    ];
    return ArticleListPage(items: items, total: items.length);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadGoldenFonts);

  testWidgets('golden article card compact', (tester) async {
    await _pumpGolden(
      tester,
      Container(
        color: const Color(0xFFF7F7F7),
        padding: const EdgeInsets.all(16),
        alignment: Alignment.topLeft,
        child: ArticleCard(article: _summary(), width: 290, height: 320),
      ),
      size: const Size(322, 352),
    );
    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/article_card_compact.png'),
      skip: _skipPixelGoldens,
    );
  });

  testWidgets('golden article card full', (tester) async {
    await _pumpGolden(
      tester,
      Container(
        color: const Color(0xFFF7F7F7),
        padding: const EdgeInsets.all(16),
        alignment: Alignment.topLeft,
        child: ArticleCard(
          article: _summary(likeCount: 2400, likedByMe: true),
          width: 358,
          height: 330,
        ),
      ),
      size: const Size(393, 366),
    );
    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/article_card_full.png'),
      skip: _skipPixelGoldens,
    );
  });

  testWidgets('golden article editor', (tester) async {
    await _pumpGolden(
      tester,
      const ArticleEditorScreen(),
      overrides: [
        articlesRepositoryProvider.overrideWithValue(
          _GoldenArticlesRepository(),
        ),
      ],
    );
    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/article_editor.png'),
      skip: _skipPixelGoldens,
    );
  });

  testWidgets('golden article reading screen', (tester) async {
    await _pumpGolden(
      tester,
      const ArticleDetailsScreen(articleId: 'article-1'),
      overrides: [
        articlesRepositoryProvider.overrideWithValue(
          _GoldenArticlesRepository(),
        ),
      ],
    );
    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/article_reading.png'),
      skip: _skipPixelGoldens,
    );
  });
}

Future<void> _pumpGolden(
  WidgetTester tester,
  Widget child, {
  Size size = _phoneSize,
  List<Override> overrides = const [],
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...testSessionOverrides(onboardingCompleted: true),
        ...overrides,
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        builder: (context, appChild) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(top: 59, bottom: 34),
              textScaler: TextScaler.noScaling,
            ),
            child: appChild!,
          );
        },
        home: RepaintBoundary(
          key: _goldenKey,
          child: Material(color: Colors.transparent, child: child),
        ),
      ),
    ),
  );
  final context = tester.element(find.byKey(_goldenKey));
  await tester.runAsync(() async {
    await Future.wait([
      for (final asset in [
        AppImages.coastPineTwilight,
        AppImages.capeFiolentFog,
        AppImages.travelerPortrait,
        AppImages.welcomeSunset,
        AppImages.coastalBayHills,
      ])
        precacheImage(AssetImage(asset), context),
    ]);
  });
  await tester.pump();
  await tester.pumpAndSettle();
}

Future<void> _loadGoldenFonts() async {
  final loader = FontLoader('Rubik')
    ..addFont(rootBundle.load('assets/fonts/Rubik-VariableFont_wght.ttf'));
  await loader.load();

  final materialIcons = File(
    '${_flutterSdkRoot().path}/bin/cache/artifacts/material_fonts/'
    'MaterialIcons-Regular.otf',
  );
  final materialLoader = FontLoader('MaterialIcons')
    ..addFont(materialIcons.readAsBytes().then(ByteData.sublistView));
  await materialLoader.load();
}

Directory _flutterSdkRoot() {
  var current = File(Platform.resolvedExecutable).parent;
  while (current.parent.path != current.path) {
    if (File('${current.path}/bin/flutter').existsSync()) {
      return current;
    }
    current = current.parent;
  }
  throw StateError('Unable to locate the active Flutter SDK');
}
