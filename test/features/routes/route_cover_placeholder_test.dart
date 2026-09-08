import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/routes/presentation/widgets/route_collapsing_header.dart';

void main() {
  testWidgets('a route with no photo says so instead of borrowing a stock one', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CustomScrollView(
          slivers: [
            RouteCollapsingHeader(
              images: const [],
              title: 'Черновик без фото',
              isFavorite: false,
              expansionProgress: 0,
              onToggleGallery: () {},
              onToggleFavorite: () {},
              onShare: () {},
              onDownload: () {},
              onBack: () {},
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Фото не загружено'), findsOneWidget);
    expect(find.byIcon(Icons.photo_camera_outlined), findsOneWidget);
  });
}
