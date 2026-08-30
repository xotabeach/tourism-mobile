import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tourism_mobile/features/route_publish/application/route_publish_controller.dart';
import 'package:tourism_mobile/features/route_publish/data/route_media_picker.dart';
import 'package:tourism_mobile/features/route_publish/domain/publish_route.dart';
import 'package:tourism_mobile/features/route_publish/domain/route_publish_repository.dart';
import 'package:tourism_mobile/features/route_publish/presentation/route_publish_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadRubik);

  testWidgets('golden fixture follows the 434 px coordinate map', (
    tester,
  ) async {
    await _pumpPublish(
      tester,
      const Size(434, 2048),
      platform: TargetPlatform.iOS,
    );

    _expectRect(tester, 'route-media-carousel', 18, 130, 399, 214);
    final firstPhoto = tester.getRect(find.byType(Image).first);
    expect(firstPhoto.left, moreOrLessEquals(18, epsilon: 1));
    expect(firstPhoto.top, moreOrLessEquals(130, epsilon: 1));
    expect(firstPhoto.width, moreOrLessEquals(162, epsilon: 1));
    expect(firstPhoto.height, moreOrLessEquals(214, epsilon: 1));
    _expectRect(tester, 'route-add-media', 18, 358, 399, 89);
    _expectRect(tester, 'route-title-field', 18, 503, 399, 41);
    final titleField = find.byKey(const ValueKey('route-title-field'));
    final titleEditable = find.descendant(
      of: titleField,
      matching: find.byType(EditableText),
    );
    expect(
      tester.getCenter(titleEditable).dy,
      moreOrLessEquals(tester.getCenter(titleField).dy, epsilon: 1),
    );
    expect(
      tester
          .getSize(
            find.descendant(of: titleField, matching: find.byType(TextField)),
          )
          .width,
      moreOrLessEquals(tester.getSize(titleField).width, epsilon: 2),
    );
    expect(
      tester
          .getSize(
            find.descendant(of: titleField, matching: find.byType(TextField)),
          )
          .height,
      moreOrLessEquals(tester.getSize(titleField).height, epsilon: 1),
    );
    expect(
      tester.getCenter(find.text('0/30')).dy,
      moreOrLessEquals(tester.getCenter(titleField).dy, epsilon: 1),
    );
    _expectRect(tester, 'route-description-field', 18, 553, 399, 102);
    _expectRect(tester, 'Стартовая точка-card', 18, 712, 399, 65);
    _expectRect(tester, 'Финишная точка-card', 18, 834, 399, 65);
    _expectRect(tester, 'route-map-preview', 18, 1163, 399, 320);
    _expectRect(tester, 'route-pace-Спокойный', 18, 1691, 127, 80);
    _expectRect(tester, 'route-action-Опубликовать маршрут', 18, 1889, 399, 62);
    _expectRect(tester, 'route-action-Сохранить черновик', 18, 1959, 399, 63);
    expect(tester.takeException(), isNull);

    // Font rasterization differs between macOS (where this baseline is
    // recorded) and the Linux GitLab runner. Keep all geometry assertions
    // cross-platform, but compare pixels only on the baseline host.
    if (Platform.isMacOS) {
      await expectLater(
        find.byKey(const ValueKey('route-publish-viewport')),
        matchesGoldenFile('../../golden/goldens/route_publish_434x2048.png'),
      );
    }
  });

  for (final configuration in const [
    (Size(320, 740), TargetPlatform.android),
    (Size(393, 852), TargetPlatform.iOS),
    (Size(768, 1024), TargetPlatform.android),
  ]) {
    testWidgets('publish route has no overflow at ${configuration.$1.width} '
        'on ${configuration.$2.name}', (tester) async {
      await _pumpPublish(tester, configuration.$1, platform: configuration.$2);
      expect(tester.takeException(), isNull);
      await tester.drag(
        find.byKey(const ValueKey('route-publish-scroll')),
        const Offset(0, -900),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Сохранить черновик'), findsOneWidget);
    });
  }

  testWidgets('media close button removes an item directly', (tester) async {
    await _pumpPublish(tester, const Size(434, 900));
    const removeKey = ValueKey('route-media-remove-golden-photo-1');
    expect(find.byKey(removeKey), findsOneWidget);
    expect(find.byKey(const ValueKey('route-media-carousel')), findsOneWidget);

    await tester.tap(find.byKey(removeKey));
    await tester.pump();

    expect(find.byKey(removeKey), findsNothing);
    expect(find.text('Удалить медиа'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('title input width stays fixed while text grows', (tester) async {
    await _pumpPublish(tester, const Size(434, 900));
    final titleField = find.byKey(const ValueKey('route-title-field'));
    final editable = find.descendant(
      of: titleField,
      matching: find.byType(EditableText),
    );
    final initialWidth = tester.getSize(editable).width;

    await tester.enterText(
      find.descendant(of: titleField, matching: find.byType(TextField)),
      'Маршрут вдоль побережья',
    );
    await tester.pump();

    expect(
      tester.getSize(editable).width,
      moreOrLessEquals(initialWidth, epsilon: 1),
    );
    expect(tester.getSize(titleField).width, 399);
    expect(tester.takeException(), isNull);
  });

  test(
    'controller prevents duplicate locations and persists a draft',
    () async {
      final drafts = _MemoryDraftRepository();
      final controller = RoutePublishController(
        mode: RoutePublishMode.production,
        drafts: drafts,
        mediaPicker: _NoopMediaPicker(),
        publication: _NoopPublicationRepository(),
      );
      addTearDown(controller.dispose);
      await Future<void>.delayed(Duration.zero);

      const location = RouteLocation(
        id: 'same',
        name: 'Точка',
        subtitle: 'Крым',
        lat: 44.5,
        lng: 34,
      );
      controller.setStart(location);
      controller.setFinish(location);
      expect(controller.state.finishError, isNotNull);

      controller.setTitle('Тестовый маршрут');
      await controller.saveDraft();
      expect(drafts.value?.title, 'Тестовый маршрут');
      expect(controller.state.message, 'Черновик сохранён');
    },
  );

  test('controller clears the local draft after publication', () async {
    const start = RouteLocation(
      id: 'start-id',
      name: 'Старт',
      subtitle: 'Крым',
      lat: 44.5,
      lng: 34,
    );
    const finish = RouteLocation(
      id: 'finish-id',
      name: 'Финиш',
      subtitle: 'Крым',
      lat: 44.6,
      lng: 34.1,
    );
    final drafts = _MemoryDraftRepository()
      ..value = const RouteDraft(
        title: 'Горный маршрут',
        media: [
          RouteMediaItem(
            id: 'photo',
            path: '/tmp/photo.jpg',
            kind: RouteMediaKind.image,
          ),
        ],
        start: start,
        finish: finish,
      );
    final publication = _NoopPublicationRepository();
    final controller = RoutePublishController(
      mode: RoutePublishMode.production,
      drafts: drafts,
      mediaPicker: _NoopMediaPicker(),
      publication: publication,
    );
    addTearDown(controller.dispose);
    await Future<void>.delayed(Duration.zero);
    controller.continueDraft();

    final id = await controller.publish();

    expect(id, 'route-id');
    expect(publication.saved, 1);
    expect(publication.submitted, 1);
    expect(drafts.value, isNull);
    expect(controller.state.message, 'Маршрут отправлен на модерацию');
  });

  test('controller asks before restoring and can start over', () async {
    final drafts = _MemoryDraftRepository()
      ..value = const RouteDraft(
        serverId: 'saved-route',
        title: 'Сохранённый маршрут',
      );
    final publication = _NoopPublicationRepository();
    final controller = RoutePublishController(
      mode: RoutePublishMode.production,
      drafts: drafts,
      mediaPicker: _NoopMediaPicker(),
      publication: publication,
    );
    addTearDown(controller.dispose);
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.draft.title, isEmpty);
    expect(controller.state.availableDraft?.title, 'Сохранённый маршрут');

    await controller.startNewDraft();

    expect(controller.state.availableDraft, isNull);
    expect(drafts.value, isNull);
    expect(publication.discarded, ['saved-route']);
  });
}

Future<void> _pumpPublish(
  WidgetTester tester,
  Size size, {
  TargetPlatform platform = TargetPlatform.android,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(platform: platform),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            size: size,
            padding: const EdgeInsets.only(top: 59),
            viewPadding: const EdgeInsets.only(top: 59),
            devicePixelRatio: 1,
            textScaler: TextScaler.noScaling,
          ),
          child: child!,
        ),
        home: const RoutePublishScreen.golden(),
      ),
    ),
  );
  await tester.runAsync(() async {
    final context = tester.element(
      find.byKey(const ValueKey('route-publish-viewport')),
    );
    await Future.wait([
      precacheImage(
        const AssetImage('assets/images/publish_photo_1.jpg'),
        context,
      ),
      precacheImage(const AssetImage('assets/images/publish_map.jpg'), context),
    ]);
  });
  await tester.pumpAndSettle();
}

void _expectRect(
  WidgetTester tester,
  String key,
  double left,
  double top,
  double width,
  double height,
) {
  final rect = tester.getRect(find.byKey(ValueKey(key)));
  expect(rect.left, moreOrLessEquals(left, epsilon: 1));
  expect(rect.top, moreOrLessEquals(top, epsilon: 1));
  expect(rect.width, moreOrLessEquals(width, epsilon: 1));
  expect(rect.height, moreOrLessEquals(height, epsilon: 1));
}

Future<void> _loadRubik() async {
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

final class _MemoryDraftRepository implements RouteDraftRepository {
  RouteDraft? value;

  @override
  Future<RouteDraft?> load() async => value;

  @override
  Future<void> save(RouteDraft draft) async => value = draft;

  @override
  Future<void> delete() async => value = null;
}

final class _NoopMediaPicker implements RouteMediaPicker {
  @override
  Future<RouteMediaItem?> pick(RouteMediaSource source) async => null;
}

final class _NoopPublicationRepository implements RoutePublicationRepository {
  int saved = 0;
  int submitted = 0;
  final discarded = <String>[];

  @override
  Future<void> discardDraft(String routeId) async => discarded.add(routeId);

  @override
  Future<RoutePublicationReceipt> saveDraft(RouteDraft draft) async {
    saved++;
    return RoutePublicationReceipt(
      id: 'route-id',
      status: RoutePublicationStatus.draft,
      updatedAt: DateTime.utc(2026),
    );
  }

  @override
  Future<RoutePublicationReceipt> submit(RouteDraft draft) async {
    submitted++;
    return RoutePublicationReceipt(
      id: 'route-id',
      status: RoutePublicationStatus.pendingReview,
      updatedAt: DateTime.utc(2026),
    );
  }

  @override
  Future<RoutePublicationReceipt> withdraw(String routeId) async {
    return RoutePublicationReceipt(
      id: routeId,
      status: RoutePublicationStatus.draft,
      updatedAt: DateTime.utc(2026),
    );
  }
}
