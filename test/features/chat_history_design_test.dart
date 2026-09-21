import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/core/theme/app_theme.dart';
import 'package:tourism_mobile/features/route_match/application/route_match_providers.dart';
import 'package:tourism_mobile/features/route_match/presentation/chat_history_screen.dart';

import '../support/test_overrides.dart';

void main() {
  testWidgets(
    'chat history: title with the count in the bar, chat-line icons',
    (tester) async {
      final loader = FontLoader('Rubik')
        ..addFont(rootBundle.load('assets/fonts/Rubik-Regular.ttf'))
        ..addFont(rootBundle.load('assets/fonts/Rubik-Medium.ttf'))
        ..addFont(rootBundle.load('assets/fonts/Rubik-SemiBold.ttf'))
        ..addFont(rootBundle.load('assets/fonts/Rubik-Bold.ttf'));
      await loader.load();
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(393, 400);
      addTearDown(() {
        tester.view
          ..resetDevicePixelRatio()
          ..resetPhysicalSize();
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: testSessionOverrides(onboardingCompleted: true),
          child: MaterialApp(
            theme: AppTheme.light,
            home: const RepaintBoundary(
              key: ValueKey('shot'),
              child: Scaffold(body: ChatHistoryScreen()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        for (final element in find.byType(Image).evaluate()) {
          await precacheImage((element.widget as Image).image, element);
        }
      });
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ChatHistoryScreen)),
      );
      final page = container.read(chatSessionsProvider).value!;
      expect(find.text('Истории чатов с ИИ (${page.total})'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(find.text('КРЫМТРИП'), findsNothing);
      expect(page.items, isNotEmpty);
      expect(find.textContaining(' • '), findsWidgets);
      final images = tester.widgetList<Image>(find.byType(Image));
      expect(
        images.any(
          (i) =>
              i.image is AssetImage &&
              (i.image as AssetImage).assetName ==
                  AppIconography.accentAsset(AppIconography.settingsChatLine),
        ),
        isTrue,
      );
    },
  );
}
