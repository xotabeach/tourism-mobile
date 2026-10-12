import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_notice.dart';
import 'package:tourism_mobile/core/device/external_maps.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/features/places/application/places_providers.dart';
import 'package:tourism_mobile/features/places/domain/place.dart';
import 'package:tourism_mobile/features/route_execution/domain/route_execution.dart';
import 'package:tourism_mobile/routing/app_router.dart';

const _muted = Color(0xFF646464);

/// Hands the stop to the maps app the device has. Says so when there is none.
Future<void> navigateToStop(
  BuildContext context,
  RouteExecutionStop stop,
) async {
  final lat = stop.lat;
  final lng = stop.lng;
  if (lat == null || lng == null) return;
  final opened = await ExternalMaps.open(
    lat: lat,
    lng: lng,
    label: stop.placeName,
  );
  if (!opened && context.mounted) {
    showAppNotice(context, 'Не нашли приложение с картами на устройстве');
  }
}

/// The card of a stop on the way: what the place is, without leaving the
/// run. The photo and the text come from the place; the name and the way
/// there work without a connection too.
Future<void> showStopCardSheet(
  BuildContext context, {
  required RouteExecutionStop stop,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    showDragHandle: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _StopCardSheet(stop: stop),
  );
}

class _StopCardSheet extends ConsumerWidget {
  const _StopCardSheet({required this.stop});

  final RouteExecutionStop stop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placeId = stop.placeId;
    final place = placeId == null
        ? null
        : ref.watch(placeDetailProvider(placeId));
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final hasPoint = stop.lat != null && stop.lng != null;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 13, 16, bottomInset + 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 66,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD3D3D3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              stop.placeName,
              style: const TextStyle(
                fontFamily: AppFonts.rubik,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                height: 1.2,
                color: AppColors.primaryInk,
              ),
            ),
            const SizedBox(height: 10),
            if (place != null)
              place.when(
                data: (detail) => _PlaceFacts(
                  place: detail,
                  config: ref.watch(appConfigProvider),
                ),
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Загружаем описание…', style: _bodyStyle),
                ),
                error: (_, _) => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Описание сейчас недоступно: нет связи.',
                    style: _bodyStyle,
                  ),
                ),
              ),
            const SizedBox(height: 14),
            if (hasPoint)
              FilledButton.icon(
                onPressed: () => unawaited(navigateToStop(context, stop)),
                icon: const Icon(Icons.near_me_outlined, size: 20),
                label: const Text('Проложить до точки'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: AppColors.primaryInk,
                  shape: const StadiumBorder(),
                ),
              ),
            if (placeId != null) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  final router = GoRouter.of(context);
                  Navigator.of(context).pop();
                  unawaited(
                    router.pushNamed(
                      AppRouteNames.placeDetailsStandalone,
                      pathParameters: {'id': placeId},
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  foregroundColor: AppColors.primaryInk,
                  shape: const StadiumBorder(),
                ),
                child: const Text('Страница места'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

const _bodyStyle = TextStyle(
  fontFamily: AppFonts.rubik,
  fontSize: 14,
  fontWeight: FontWeight.w400,
  height: 1.35,
  color: _muted,
);

class _PlaceFacts extends StatelessWidget {
  const _PlaceFacts({required this.place, required this.config});

  final PlaceDetail place;
  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    final cover = place.imageUrls.firstOrNull ?? place.coverImageUrl;
    final resolved = AppImages.resolveMediaUrl(config, cover);
    final text = (place.description ?? '').trim().isNotEmpty
        ? place.description!.trim()
        : (place.shortDescription ?? '').trim();
    final address = (place.address ?? '').trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (resolved != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image(
                image: AppImages.imageProvider(resolvedUrl: resolved),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const ColoredBox(color: Color(0xFFEDEDED)),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (text.isNotEmpty)
          Text(
            text,
            maxLines: 8,
            overflow: TextOverflow.ellipsis,
            style: _bodyStyle.copyWith(color: AppColors.primaryInk),
          ),
        if (address.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Адрес: $address', style: _bodyStyle),
        ],
        for (final warning in place.safetyWarnings) ...[
          const SizedBox(height: 8),
          Text('Важно: $warning', style: _bodyStyle),
        ],
      ],
    );
  }
}
