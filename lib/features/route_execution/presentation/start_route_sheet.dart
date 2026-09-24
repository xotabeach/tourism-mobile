import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_hero_card.dart'
    show difficultyLabel, formatDistanceKm;

// Same palette as the DESIGN-4 run sheets (mark_confirm_dialog.dart).
const _pillInk = Color(0xFF212121);
const _pillOutline = Color(0xFFD7D7D7);
const _muted = Color(0xFF646464);
const _chipFill = Color(0xFFF3F3F3);

/// «Start this route?» before the run screen opens (FRONTEND-45): a stray
/// tap on «Пройти маршрут» no longer starts a run. True only on «Запустить».
///
/// [route] is what the route screen already shows; without it (not loaded
/// yet) the sheet asks with no summary rather than fetching.
Future<bool> showStartRouteSheet(
  BuildContext context, {
  required AppConfig config,
  required RouteDetail? route,
}) async {
  final start = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    showDragHandle: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => StartRouteSheet(config: config, route: route),
  );
  return start == true;
}

String _durationLabel(RouteDetail route) {
  final seconds = route.routing?.totalDurationSeconds;
  final minutes = seconds != null
      ? (seconds / 60).ceil()
      : route.estimatedDurationMinutes;
  if (minutes == null) return '';
  if (minutes < 60) return '$minutes мин';
  final rest = minutes % 60;
  return rest == 0 ? '${minutes ~/ 60} ч' : '${minutes ~/ 60} ч $rest мин';
}

String _plural(int n, String one, String few, String many) {
  final mod100 = n % 100;
  final mod10 = n % 10;
  if (mod100 >= 11 && mod100 <= 14) return many;
  if (mod10 == 1) return one;
  if (mod10 >= 2 && mod10 <= 4) return few;
  return many;
}

/// Facts in the order the route screen lists them; empty ones left out.
List<String> startRouteFacts(RouteDetail route) {
  final stops = route.stops.isNotEmpty ? route.stops.length : route.stopsCount;
  final days = route.days.length;
  return [
    if (days > 1) '$days ${_plural(days, 'день', 'дня', 'дней')}',
    if (_durationLabel(route) case final duration when duration.isNotEmpty)
      duration,
    if (route.distanceMeters != null) formatDistanceKm(route.distanceMeters),
    if (stops > 0) '$stops ${_plural(stops, 'точка', 'точки', 'точек')}',
    if (route.difficulty != null) difficultyLabel(route.difficulty),
  ];
}

class StartRouteSheet extends StatelessWidget {
  const StartRouteSheet({required this.config, required this.route, super.key});

  final AppConfig config;
  final RouteDetail? route;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final route = this.route;
    final cover = route?.coverImageUrl;
    return SingleChildScrollView(
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
          const SizedBox(height: 20),
          if (route != null && cover != null && cover.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: ExcludeSemantics(
                  child: AppImages.coverImage(
                    config: config,
                    coverImageUrl: cover,
                    fallbackSeed: route.slug,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          const Text(
            'Начать маршрут?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.rubik,
              fontSize: 14,
              fontWeight: FontWeight.w400,
              height: 1.2,
              color: _muted,
            ),
          ),
          if (route != null) ...[
            const SizedBox(height: 6),
            Text(
              route.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppFonts.rubik,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                height: 1.2,
                color: AppColors.primaryInk,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final fact in startRouteFacts(route)) _FactChip(fact),
              ],
            ),
          ],
          const SizedBox(height: 20),
          _PillButton(
            label: 'Запустить',
            filled: true,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: 8),
          _PillButton(
            label: 'Отмена',
            filled: false,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}

class _FactChip extends StatelessWidget {
  const _FactChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const ShapeDecoration(
        color: _chipFill,
        shape: StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: AppFonts.rubik,
            fontSize: 13,
            fontWeight: FontWeight.w400,
            height: 1.2,
            color: AppColors.primaryInk,
          ),
        ),
      ),
    );
  }
}

/// Black filled or white outlined pill, as on the DESIGN-4 sheets.
class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.filled,
    required this.onPressed,
  });

  final String label;
  final bool filled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: filled ? _pillInk : Colors.white,
        shape: StadiumBorder(
          side: filled
              ? BorderSide.none
              : const BorderSide(color: _pillOutline, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            height: 56,
            width: double.infinity,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: AppFonts.rubik,
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  height: 1.2,
                  color: filled ? Colors.white : AppColors.primaryInk,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
