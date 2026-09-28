import 'package:flutter/material.dart';

import 'package:tourism_mobile/features/route_match/domain/route_match_models.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_builder_design_tokens.dart';

typedef RoutePx = double Function(double);

/// Side-by-side figures of a «сравни эти варианты» answer (FRONTEND-46).
///
/// The model's prose used to carry every number, a wall of text nobody could
/// scan. Here each route gets bars for time and length scaled against the
/// longest one, a difficulty scale and the server's badges, and the text
/// above only says what differs in substance.
class ChatRouteComparison extends StatelessWidget {
  const ChatRouteComparison({
    required this.px,
    required this.routes,
    this.onOpenRoute,
    super.key,
  });

  final RoutePx px;
  final List<ComparisonRouteItem> routes;
  final ValueChanged<String>? onOpenRoute;

  @override
  Widget build(BuildContext context) {
    final maxMinutes = _max(routes.map((route) => route.durationMinutes));
    final maxKm = _max(routes.map((route) => route.distanceKm));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < routes.length; i++) ...[
          if (i > 0) SizedBox(height: px(8)),
          _ComparisonRow(
            px: px,
            route: routes[i],
            maxMinutes: maxMinutes,
            maxKm: maxKm,
            onOpen: onOpenRoute == null
                ? null
                : () => onOpenRoute!(routes[i].routeId),
          ),
        ],
      ],
    );
  }

  static double? _max(Iterable<num?> values) {
    double? best;
    for (final value in values) {
      if (value != null && value > 0 && (best == null || value > best)) {
        best = value.toDouble();
      }
    }
    return best;
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({
    required this.px,
    required this.route,
    required this.maxMinutes,
    required this.maxKm,
    required this.onOpen,
  });

  final RoutePx px;
  final ComparisonRouteItem route;
  final double? maxMinutes;
  final double? maxKm;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(px(12));
    final minutes = route.durationMinutes;
    final km = route.distanceKm;
    final footer = [
      ?route.transportLabel,
      if (route.stopsCount != null) _stopsLabel(route.stopsCount!),
    ].join(' · ');
    return Semantics(
      button: onOpen != null,
      label: route.title,
      child: Material(
        color: RouteBuilderDesignTokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: RouteBuilderDesignTokens.lightBorder,
            width: px(1),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: EdgeInsets.fromLTRB(px(10), px(9), px(8), px(10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        route.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: RouteBuilderDesignTokens.rubik(
                          fontSize: px(13),
                          weight: FontWeight.w600,
                          color: RouteBuilderDesignTokens.textPrimary,
                          height: 1.15,
                        ),
                      ),
                    ),
                    if (onOpen != null)
                      Icon(
                        Icons.chevron_right_rounded,
                        size: px(18),
                        color: RouteBuilderDesignTokens.textSecondary,
                      ),
                  ],
                ),
                if (route.badges.isNotEmpty) ...[
                  SizedBox(height: px(6)),
                  Wrap(
                    spacing: px(4),
                    runSpacing: px(4),
                    children: [
                      for (final badge in route.badges)
                        _Badge(px: px, text: badge),
                    ],
                  ),
                ],
                if (minutes != null && maxMinutes != null) ...[
                  SizedBox(height: px(8)),
                  _MetricBar(
                    px: px,
                    label: 'Время',
                    share: minutes / maxMinutes!,
                    value: _durationLabel(minutes),
                  ),
                ],
                if (km != null && maxKm != null) ...[
                  SizedBox(height: px(6)),
                  _MetricBar(
                    px: px,
                    label: 'Путь',
                    share: km / maxKm!,
                    value: '${_decimal(km)} км',
                  ),
                ],
                if (route.difficultyLevel != null) ...[
                  SizedBox(height: px(7)),
                  _DifficultyScale(
                    px: px,
                    level: route.difficultyLevel!,
                    label: route.difficultyLabel,
                  ),
                ],
                if (footer.isNotEmpty) ...[
                  SizedBox(height: px(6)),
                  Text(
                    footer,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RouteBuilderDesignTokens.rubik(
                      fontSize: px(11),
                      color: RouteBuilderDesignTokens.textSecondary,
                      height: 1.1,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.px, required this.text});

  final RoutePx px;
  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: RouteBuilderDesignTokens.selectedLightBlue,
        borderRadius: BorderRadius.circular(px(8)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: px(6), vertical: px(3)),
        child: Text(
          text,
          style: RouteBuilderDesignTokens.rubik(
            fontSize: px(10),
            weight: FontWeight.w500,
            color: RouteBuilderDesignTokens.primaryBlue,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}

class _MetricBar extends StatelessWidget {
  const _MetricBar({
    required this.px,
    required this.label,
    required this.share,
    required this.value,
  });

  final RoutePx px;
  final String label;

  /// This route's value against the largest one, 0..1.
  final double share;
  final String value;

  @override
  Widget build(BuildContext context) {
    final captionStyle = RouteBuilderDesignTokens.rubik(
      fontSize: px(11),
      color: RouteBuilderDesignTokens.textSecondary,
      height: 1.1,
    );
    return Row(
      children: [
        SizedBox(
          width: px(38),
          child: Text(label, style: captionStyle),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(px(3)),
            child: SizedBox(
              height: px(6),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(
                    color: RouteBuilderDesignTokens.chatScrollTrack,
                  ),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    // A sliver stays visible for the shortest route.
                    widthFactor: share.clamp(0.06, 1.0),
                    child: const ColoredBox(
                      color: RouteBuilderDesignTokens.primaryBlue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(
          width: px(50),
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 1,
            style: RouteBuilderDesignTokens.rubik(
              fontSize: px(11),
              weight: FontWeight.w600,
              color: RouteBuilderDesignTokens.textPrimary,
              height: 1.1,
            ),
          ),
        ),
      ],
    );
  }
}

class _DifficultyScale extends StatelessWidget {
  const _DifficultyScale({required this.px, required this.level, this.label});

  final RoutePx px;
  final int level;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Сложность: ${label ?? '$level из 4'}',
      excludeSemantics: true,
      child: Row(
        children: [
          SizedBox(
            width: px(38),
            child: Text(
              'Нагр.',
              style: RouteBuilderDesignTokens.rubik(
                fontSize: px(11),
                color: RouteBuilderDesignTokens.textSecondary,
                height: 1.1,
              ),
            ),
          ),
          for (var i = 1; i <= 4; i++) ...[
            if (i > 1) SizedBox(width: px(3)),
            Container(
              width: px(14),
              height: px(6),
              decoration: BoxDecoration(
                color: i <= level
                    ? RouteBuilderDesignTokens.primaryBlue
                    : RouteBuilderDesignTokens.chatScrollTrack,
                borderRadius: BorderRadius.circular(px(3)),
              ),
            ),
          ],
          if (label != null) ...[
            SizedBox(width: px(6)),
            Expanded(
              child: Text(
                label!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: RouteBuilderDesignTokens.rubik(
                  fontSize: px(11),
                  color: RouteBuilderDesignTokens.textPrimary,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _durationLabel(int minutes) {
  if (minutes < 60) {
    return '$minutes мин';
  }
  final hours = minutes / 60;
  return '${_decimal(hours)} ч';
}

String _decimal(double value) {
  final rounded = (value * 10).round() / 10;
  final text = rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(1);
  return text.replaceAll('.', ',');
}

String _stopsLabel(int count) {
  final mod10 = count % 10;
  final mod100 = count % 100;
  final word = mod10 == 1 && mod100 != 11
      ? 'точка'
      : mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)
      ? 'точки'
      : 'точек';
  return '$count $word';
}
