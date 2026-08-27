import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/core/design/app_motion.dart';
import 'package:tourism_mobile/core/performance/app_perf.dart';
import 'package:tourism_mobile/routing/shell/app_shell_screen.dart';

const _navSurfaceKey = ValueKey('nav-rebuild-surface');

/// The floating nav bar used to drive every frame through `setState`, which
/// rebuilt the whole bar — five destination slots, each with its own
/// `Semantics`/`Tooltip`/`InkResponse` and two `AppAssetIcon`s — sixty times a
/// second for the length of a transition. These tests pin the scope of a
/// frame: only the geometry wrappers may rebuild while the bar animates.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadRubik);

  testWidgets('travel frames never rebuild a destination slot', (tester) async {
    final harness = await _pumpNav(tester);

    // Driven through `currentIndex` rather than a tap: a tap additionally
    // wakes Material's ink/focus bookkeeping, whose own settle passes would
    // mask what is being measured here — the cost of an animation frame.
    harness.currentState!.select(4);
    // The index change legitimately rebuilds the bar once (selected-state
    // semantics move). Measurement starts on the frame after it.
    await tester.pump();

    final perFrame = await _recordFrames(tester, frames: 8);
    final all = perFrame.expand((frame) => frame).toList();
    // Sanity: the bar really was animating across those frames.
    expect(all, contains('AnimatedBuilder'));

    // Nothing but the geometry wrappers: the slot, its tooltip and its gesture
    // target are stable widget instances, so the framework skips those
    // subtrees outright. Driving frames through `setState` rebuilt one pass of
    // all five slots in *every* frame.
    for (final frame in perFrame) {
      expect(frame.where((name) => name.startsWith('_NavSlot')), isEmpty);
      expect(frame.where((name) => name.startsWith('Tooltip')), isEmpty);
      expect(frame.where((name) => name.startsWith('InkResponse')), isEmpty);
    }
  });

  testWidgets('collapsing into detail chrome does not re-inflate the slots', (
    tester,
  ) async {
    final harness = await _pumpNav(tester);
    // Ink and tooltip state live in the slot's elements. A collapse translates
    // every slot sideways, and it must do that without changing the shape of
    // the tree above them — otherwise each slot is torn down and rebuilt.
    harness.currentState!.setDetailMode(detail: true);
    await tester.pump();

    final rebuilt = await _recordFrames(tester, frames: 8);

    expect(rebuilt.expand((frame) => frame), contains('AnimatedBuilder'));
    for (final frame in rebuilt) {
      expect(frame.where((name) => name.startsWith('_NavSlot')), isEmpty);
      expect(frame.where((name) => name.startsWith('Tooltip')), isEmpty);
    }
  });

  testWidgets('press feedback lands on the touch frame, with no ripple', (
    tester,
  ) async {
    await _pumpNav(tester);
    final resting = _iconAlpha(tester, AppIconography.profile);

    final gesture = await tester.startGesture(
      tester.getCenter(find.bySemanticsLabel('Профиль')),
    );
    // A single zero-duration frame: the feedback must already be there. An
    // ink ripple only starts spreading here and needs ~200 ms to read.
    await tester.pump();
    expect(_iconAlpha(tester, AppIconography.profile), lessThan(resting));

    // And the ripple really is off, rather than merely hidden under the dim.
    expect(
      tester
          .widgetList<InkResponse>(find.byType(InkResponse))
          .every((ink) => ink.splashFactory == NoSplash.splashFactory),
      isTrue,
    );

    // Cancelled rather than released, so the selection does not move and the
    // icon has a resting value to come back to.
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(_iconAlpha(tester, AppIconography.profile), resting);
  });

  testWidgets('icon tint lands well before the indicator finishes travelling', (
    tester,
  ) async {
    final harness = await _pumpNav(tester);
    expect(_selectedIconAlpha(tester, AppIconography.profileSelected), 0);

    harness.currentState!.select(4);
    await tester.pump();
    await tester.pump(AppPerf.motion(AppMotion.navTint));

    // Tint is done…
    expect(_selectedIconAlpha(tester, AppIconography.profileSelected), 1);
    // …while the droplet is still on its way. Tying the two together (the old
    // `1 - |position - index|` weight) smeared this crossfade across the whole
    // travel, which is what made the switch feel slow.
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pumpAndSettle();
    expect(_selectedIconAlpha(tester, AppIconography.profileSelected), 1);
  });
}

/// Pumps [frames] animation frames, returning what each one rebuilt.
Future<List<List<String>>> _recordFrames(
  WidgetTester tester, {
  required int frames,
}) async {
  final perFrame = <List<String>>[];
  var current = <String>[];
  debugOnRebuildDirtyWidget = (element, _) =>
      current.add(element.widget.toStringShort());
  addTearDown(() => debugOnRebuildDirtyWidget = null);
  for (var frame = 0; frame < frames; frame++) {
    current = <String>[];
    await tester.pump(const Duration(milliseconds: 16));
    perFrame.add(current);
  }
  debugOnRebuildDirtyWidget = null;
  return perFrame;
}

double _iconAlpha(WidgetTester tester, String asset) =>
    _selectedIconAlpha(tester, asset);

double _selectedIconAlpha(WidgetTester tester, String asset) {
  final icon = tester.widget<AppAssetIcon>(
    find.byWidgetPredicate(
      (widget) => widget is AppAssetIcon && widget.asset == asset,
    ),
  );
  return icon.color?.a ?? 1;
}

Future<GlobalKey<_NavHarnessState>> _pumpNav(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(393, 180));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final harness = GlobalKey<_NavHarnessState>();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RepaintBoundary(
        key: _navSurfaceKey,
        child: ColoredBox(
          color: const Color(0xFFF7F7F7),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _NavHarness(key: harness),
            ),
          ),
        ),
      ),
    ),
  );
  final context = tester.element(find.byKey(_navSurfaceKey));
  await tester.runAsync(() async {
    await Future.wait([
      for (final asset in AppIconography.bundledAssets)
        precacheImage(AssetImage(asset), context),
    ]);
  });
  await tester.pumpAndSettle();
  return harness;
}

class _NavHarness extends StatefulWidget {
  const _NavHarness({super.key});

  @override
  State<_NavHarness> createState() => _NavHarnessState();
}

class _NavHarnessState extends State<_NavHarness> {
  var _index = 0;
  var _detail = false;

  void select(int index) => setState(() => _index = index);

  void setDetailMode({required bool detail}) =>
      setState(() => _detail = detail);

  @override
  Widget build(BuildContext context) {
    return AppFloatingNavBar(
      currentIndex: _index,
      detailMode: _detail,
      compactDestinationIndex: _index,
      onTap: select,
    );
  }
}

Future<void> _loadRubik() async {
  final loader = FontLoader('Rubik')
    ..addFont(rootBundle.load('assets/fonts/Rubik-VariableFont_wght.ttf'));
  await loader.load();
}
