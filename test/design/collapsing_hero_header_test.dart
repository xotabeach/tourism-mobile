import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/design/components/collapsing_hero_header.dart';

void main() {
  testWidgets('hero media keeps a constant slot while the header collapses', (
    tester,
  ) async {
    // Regression: the media used to be a SizedBox under StackFit.expand, so it
    // was force-fit to the shrinking extent. Children that key their decode
    // size on constraints (AppImages.coverImage) then re-resolved their
    // provider on every pixel of scroll and flashed their placeholder.
    final seen = <Size>[];

    await tester.pumpWidget(
      MaterialApp(
        home: CustomScrollView(
          slivers: [
            CollapsingHeroSliver(
              expandedHeight: 320,
              collapsedHeight: 56,
              background: LayoutBuilder(
                builder: (context, constraints) {
                  seen.add(constraints.biggest);
                  return const ColoredBox(color: Colors.green);
                },
              ),
              builder: (context, t, shrinkOffset, currentExtent) =>
                  const SizedBox.shrink(),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 2000)),
          ],
        ),
      ),
    );

    for (var offset = 40.0; offset <= 320; offset += 40) {
      tester.state<ScrollableState>(find.byType(Scrollable)).position.jumpTo(
        offset,
      );
      await tester.pump();
    }

    expect(seen, isNotEmpty);
    expect(seen.map((size) => size.height).toSet(), {320.0});
  });

  testWidgets('sheet lip stays opaque and only flattens its radius', (
    tester,
  ) async {
    Future<BorderRadius> radiusAt(double progress) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            fit: StackFit.expand,
            children: [CollapsingSheetLip(progress: progress)],
          ),
        ),
      );
      final decorated = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(CollapsingSheetLip),
          matching: find.byType(DecoratedBox),
        ),
      );
      final decoration = decorated.decoration as BoxDecoration;
      // Structure, not an overlay: it must never be faded out.
      expect(decoration.color!.a, 1);
      expect(
        find.ancestor(
          of: find.byType(CollapsingSheetLip),
          matching: find.byType(Opacity),
        ),
        findsNothing,
      );
      return decoration.borderRadius! as BorderRadius;
    }

    expect((await radiusAt(0)).topLeft.x, 24);
    expect((await radiusAt(0.275)).topLeft.x, closeTo(12, 0.01));
    expect((await radiusAt(0.55)).topLeft.x, 0);
    expect((await radiusAt(1)).topLeft.x, 0);
  });
}
