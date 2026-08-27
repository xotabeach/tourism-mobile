import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/routing/shell/app_shell_screen.dart';
import 'package:tourism_mobile/routing/shell/tab_scroll_to_top.dart';

const _surfaceKey = ValueKey('nav-collapse-surface');
const _compactKey = ValueKey('expand-detail-navigation');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadRubik);

  testWidgets('collapse follows scroll direction, not absolute offset', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    late WidgetRef ref;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, widgetRef, _) {
            ref = widgetRef;
            return const SizedBox();
          },
        ),
      ),
    );
    bool collapsed() => container.read(tabNavCollapsedProvider(0));

    // Near the top the bar stays whole however the list moves.
    syncTabScrolledDown(ref, 0, 10);
    expect(collapsed(), isFalse);

    syncTabScrolledDown(ref, 0, 200);
    expect(collapsed(), isTrue);

    // Jitter below the delta must not flap it back open.
    syncTabScrolledDown(ref, 0, 195);
    expect(collapsed(), isTrue);

    // A real scroll up reopens it *mid-list* — this is the part an
    // offset-only rule gets wrong, keeping the bar folded until the very top.
    syncTabScrolledDown(ref, 0, 150);
    expect(collapsed(), isFalse);
    expect(container.read(tabScrolledDownProvider(0)), isTrue);

    syncTabScrolledDown(ref, 0, 230);
    expect(collapsed(), isTrue);

    syncTabScrolledDown(ref, 0, 0);
    expect(collapsed(), isFalse);
    expect(container.read(tabScrolledDownProvider(0)), isFalse);
  });

  testWidgets('scrolling down folds the bar onto the active droplet', (
    tester,
  ) async {
    final harness = await _pumpNav(tester);
    expect(find.byKey(_compactKey), findsNothing);
    final resting = _iconAlpha(tester, AppIconography.profile);
    expect(resting, greaterThan(0));

    harness.currentState!.setCollapsed(collapsed: true);
    await tester.pumpAndSettle();
    expect(find.byKey(_compactKey), findsOneWidget);
    // Only the active destination survives the fold.
    expect(_iconAlpha(tester, AppIconography.profile), 0);

    // Tapping the droplet reopens the bar without waiting for a scroll.
    await tester.tap(find.byKey(_compactKey));
    await tester.pumpAndSettle();
    expect(find.byKey(_compactKey), findsNothing);
    expect(_iconAlpha(tester, AppIconography.profile), resting);

    // …and it is not timed back out from under the user, unlike detail chrome.
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();
    expect(find.byKey(_compactKey), findsNothing);

    harness.currentState!.setCollapsed(collapsed: false);
    await tester.pumpAndSettle();
    expect(find.byKey(_compactKey), findsNothing);
    expect(_iconAlpha(tester, AppIconography.profile), resting);
  });
}

double _iconAlpha(WidgetTester tester, String asset) {
  final icon = tester.widget<AppAssetIcon>(
    find.byWidgetPredicate(
      (widget) => widget is AppAssetIcon && widget.asset == asset,
    ),
  );
  return icon.color?.a ?? 1;
}

Future<GlobalKey<_CollapseHarnessState>> _pumpNav(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(393, 180));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final harness = GlobalKey<_CollapseHarnessState>();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RepaintBoundary(
        key: _surfaceKey,
        child: ColoredBox(
          color: const Color(0xFFF7F7F7),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _CollapseHarness(key: harness),
            ),
          ),
        ),
      ),
    ),
  );
  final context = tester.element(find.byKey(_surfaceKey));
  await tester.runAsync(() async {
    await Future.wait([
      for (final asset in AppIconography.bundledAssets)
        precacheImage(AssetImage(asset), context),
    ]);
  });
  await tester.pumpAndSettle();
  return harness;
}

class _CollapseHarness extends StatefulWidget {
  const _CollapseHarness({super.key});

  @override
  State<_CollapseHarness> createState() => _CollapseHarnessState();
}

class _CollapseHarnessState extends State<_CollapseHarness> {
  var _collapsed = false;

  void setCollapsed({required bool collapsed}) =>
      setState(() => _collapsed = collapsed);

  @override
  Widget build(BuildContext context) {
    return AppFloatingNavBar(
      currentIndex: 0,
      scrollCollapsed: _collapsed,
      onTap: (_) {},
    );
  }
}

Future<void> _loadRubik() async {
  final loader = FontLoader('Rubik')
    ..addFont(rootBundle.load('assets/fonts/Rubik-VariableFont_wght.ttf'));
  await loader.load();
}
