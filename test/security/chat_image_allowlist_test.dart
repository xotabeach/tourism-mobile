import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/features/route_match/domain/route_match_models.dart';
import 'package:tourism_mobile/features/route_match/presentation/widgets/chat_place_chip.dart';
import 'package:tourism_mobile/features/route_match/presentation/widgets/chat_route_proposal_card.dart';

/// Production-like config so `resolveMediaUrl` rejects non-API hosts and
/// non-http(s) schemes — the same allowlist `AppImages.coverImage` uses.
const _prodConfig = AppConfig(
  environment: AppEnvironment.production,
  apiBaseUrl: 'https://api.crimeatrip.test',
  appName: 'CrimeaTrip',
  dataSource: AppDataSource.api,
);

Widget _wrap(Widget child) {
  return ProviderScope(
    overrides: [appConfigProvider.overrideWithValue(_prodConfig)],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

bool _isRawNetworkImage(Widget widget) {
  return widget is Image && widget.image is NetworkImage;
}

void main() {
  testWidgets('chat images skip javascript URLs instead of Image.network', (
    tester,
  ) async {
    const hostile = 'javascript:alert(1)';

    await tester.pumpWidget(
      _wrap(const ChatPlaceChip(title: 'Ласточкино гнездо', imageUrl: hostile)),
    );
    expect(find.byWidgetPredicate(_isRawNetworkImage), findsNothing);
    expect(find.byType(CachedNetworkImage), findsNothing);

    await tester.pumpWidget(
      _wrap(
        const CatalogRoutePreviewHeader(
          title: 'Ялта · море',
          coverUrl: hostile,
        ),
      ),
    );
    expect(find.byWidgetPredicate(_isRawNetworkImage), findsNothing);
    expect(find.byType(CachedNetworkImage), findsNothing);

    await tester.pumpWidget(
      _wrap(
        const ChatRouteProposalCard(
          card: RouteProposalCardData(
            proposalId: 'p-hostile',
            title: 'Собранный маршрут',
            stopsCount: 3,
            durationMinutes: 180,
            cardVariant: RouteProposalCardVariant.assembled,
            galleryUrls: [hostile],
          ),
        ),
      ),
    );
    expect(find.byWidgetPredicate(_isRawNetworkImage), findsNothing);
    expect(find.byType(CachedNetworkImage), findsNothing);
  });

  testWidgets('chat images skip off-origin https URLs in production', (
    tester,
  ) async {
    const offOrigin = 'https://evil.example/cover.jpg';

    await tester.pumpWidget(
      _wrap(const ChatPlaceChip(title: 'Форос', imageUrl: offOrigin)),
    );
    expect(find.byWidgetPredicate(_isRawNetworkImage), findsNothing);
    expect(find.byType(CachedNetworkImage), findsNothing);
  });
}
