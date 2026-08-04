import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/core/design/app_motion.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_builder_design_tokens.dart';

typedef RoutePx = double Function(double);

enum RouteMatchMode { params, ai }

enum RouteTripType { romance, rest, adventure, active }

enum RouteDurationOption { d1_2, d3_5, d6_7, d7plus }

enum RoutePace { calm, moderate, active }

class RouteChatMessage {
  const RouteChatMessage({
    required this.fromAgent,
    required this.text,
    required this.time,
    this.isCrisis = false,
  });

  final bool fromAgent;
  final String text;
  final String time;
  final bool isCrisis;
}

// ── Header ──────────────────────────────────────────────────────────────────

class RouteHeader extends StatelessWidget {
  const RouteHeader({required this.px, this.includeTopInset = true, super.key});

  final RoutePx px;
  final bool includeTopInset;

  @override
  Widget build(BuildContext context) {
    final topInset = includeTopInset ? MediaQuery.paddingOf(context).top : 0.0;
    final height = topInset + px(81);
    final radius = Radius.circular(px(22));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            bottomLeft: radius,
            bottomRight: radius,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/route_header.jpg',
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.08),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.17),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0x42000000)],
                    stops: [0.45, 1],
                  ),
                ),
              ),
              Positioned(
                left: px(16),
                right: px(16),
                top: topInset + px(24),
                child: Text(
                  'ПОСТРОЙ МАРШРУТ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RouteBuilderDesignTokens.rubik(
                    fontSize: px(24),
                    weight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.0,
                    // Instruction ~1.6 felt too open on Rubik Variable; keep light tracking.
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              Positioned(
                left: px(16),
                right: px(16),
                top: topInset + px(55),
                child: Text(
                  'Подбери маршрут для себя по всем параметрам',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RouteBuilderDesignTokens.rubik(
                    fontSize: px(14),
                    weight: FontWeight.w400,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Mode switcher ───────────────────────────────────────────────────────────

class RouteModeSwitcher extends StatefulWidget {
  const RouteModeSwitcher({
    required this.px,
    required this.mode,
    required this.onChanged,
    super.key,
  });

  final RoutePx px;
  final RouteMatchMode mode;
  final ValueChanged<RouteMatchMode> onChanged;

  /// Equal mid-point is 0.5; selected grows toward [_expandedShare].
  static const double _expandedShare = 0.62;
  static const double _shrunkShare = 0.38;

  @override
  State<RouteModeSwitcher> createState() => _RouteModeSwitcherState();
}

class _RouteModeSwitcherState extends State<RouteModeSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late RouteMatchMode _visualMode;

  @override
  void initState() {
    super.initState();
    _visualMode = widget.mode;
    final initial = widget.mode == RouteMatchMode.params ? 1.0 : 0.0;
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.modeMorph,
      value: initial,
    );
  }

  @override
  void didUpdateWidget(covariant RouteModeSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_visualMode == widget.mode) {
      return;
    }
    _animateToMode(widget.mode);
  }

  void _animateToMode(RouteMatchMode mode) {
    _visualMode = mode;
    final target = mode == RouteMatchMode.params ? 1.0 : 0.0;
    final remaining = (target - _controller.value).abs();
    final duration = MediaQuery.disableAnimationsOf(context)
        ? AppMotion.reduced
        : Duration(
            microseconds: math.max(
              AppMotion.fast.inMicroseconds,
              (AppMotion.modeMorph.inMicroseconds * remaining).round(),
            ),
          );
    unawaited(
      _controller.animateTo(
        target,
        duration: duration,
        // Ease the travelled distance, not the absolute controller value.
        // Applying a curve to the absolute value made the 1→0 (AI) direction
        // start almost flat while the reverse direction reacted immediately.
        curve: AppMotion.modeMorphCurve,
      ),
    );
  }

  void _selectMode(RouteMatchMode mode) {
    if (_visualMode == mode) {
      return;
    }
    // Start the visual morph inside the pointer event. Waiting for the parent
    // rebuild adds a perceptible one-frame pause, especially on 60 Hz devices.
    _animateToMode(mode);
    widget.onChanged(mode);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final px = widget.px;
    final height = px(36);
    final gap = px(8);

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value;
              final available = constraints.maxWidth - gap;
              final paramsShare =
                  lerpDouble(
                    RouteModeSwitcher._shrunkShare,
                    RouteModeSwitcher._expandedShare,
                    t,
                  ) ??
                  RouteModeSwitcher._expandedShare;
              final paramsWidth = available * paramsShare;
              final aiLeft = paramsWidth + gap;
              final aiWidth = constraints.maxWidth - aiLeft;
              return Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        key: const ValueKey('route-mode-switch-paint'),
                        painter: _RouteModeSwitchPainter(
                          progress: t,
                          gap: gap,
                          radius: px(8),
                          borderWidth: px(1.25),
                        ),
                      ),
                    ),
                  ),
                  _ModeHitTarget(
                    key: const ValueKey('route-mode-params'),
                    left: 0,
                    width: paramsWidth,
                    height: height,
                    radius: px(8),
                    label: 'По параметрам',
                    semanticsLabel: 'Режим по параметрам',
                    selected: widget.mode == RouteMatchMode.params,
                    fontWeight: FontWeight.lerp(
                      FontWeight.w400,
                      FontWeight.w500,
                      t,
                    )!,
                    textColor: Color.lerp(
                      RouteBuilderDesignTokens.textSecondary,
                      RouteBuilderDesignTokens.textPrimary,
                      t,
                    )!,
                    fontSize: px(16),
                    onTap: () => _selectMode(RouteMatchMode.params),
                  ),
                  _ModeHitTarget(
                    key: const ValueKey('route-mode-ai'),
                    left: aiLeft,
                    width: aiWidth,
                    height: height,
                    radius: px(8),
                    label: 'Подбор с ИИ',
                    semanticsLabel: 'Режим подбор с ИИ',
                    selected: widget.mode == RouteMatchMode.ai,
                    fontWeight: FontWeight.lerp(
                      FontWeight.w400,
                      FontWeight.w500,
                      1 - t,
                    )!,
                    textColor: Colors.white,
                    fontSize: px(16),
                    onTap: () => _selectMode(RouteMatchMode.ai),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _ModeHitTarget extends StatelessWidget {
  const _ModeHitTarget({
    required this.left,
    required this.width,
    required this.height,
    required this.radius,
    required this.label,
    required this.semanticsLabel,
    required this.selected,
    required this.fontWeight,
    required this.textColor,
    required this.fontSize,
    required this.onTap,
    super.key,
  });

  final double left;
  final double width;
  final double height;
  final double radius;
  final String label;
  final String semanticsLabel;
  final bool selected;
  final FontWeight fontWeight;
  final Color textColor;
  final double fontSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      width: width,
      height: height,
      child: Semantics(
        excludeSemantics: true,
        button: true,
        selected: selected,
        label: semanticsLabel,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(radius),
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: RouteBuilderDesignTokens.rubik(
                  fontSize: fontSize,
                  weight: fontWeight,
                  color: textColor,
                  height: 1.0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RouteModeSwitchPainter extends CustomPainter {
  const _RouteModeSwitchPainter({
    required this.progress,
    required this.gap,
    required this.radius,
    required this.borderWidth,
  });

  final double progress;
  final double gap;
  final double radius;
  final double borderWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final available = size.width - gap;
    final paramsShare = lerpDouble(
      RouteModeSwitcher._shrunkShare,
      RouteModeSwitcher._expandedShare,
      progress,
    )!;
    final paramsWidth = available * paramsShare;
    final aiLeft = paramsWidth + gap;
    final paramsRect = Rect.fromLTWH(0, 0, paramsWidth, size.height);
    final aiRect = Rect.fromLTWH(aiLeft, 0, size.width - aiLeft, size.height);
    final paramsRRect = RRect.fromRectAndRadius(
      paramsRect,
      Radius.circular(radius),
    );
    final aiRRect = RRect.fromRectAndRadius(aiRect, Radius.circular(radius));

    canvas.drawRRect(
      paramsRRect,
      Paint()
        ..color = Color.lerp(
          RouteBuilderDesignTokens.background,
          RouteBuilderDesignTokens.surface,
          progress,
        )!,
    );
    canvas.drawRRect(
      paramsRRect,
      Paint()
        ..color = Color.lerp(
          RouteBuilderDesignTokens.textSecondary,
          RouteBuilderDesignTokens.primaryBlue,
          progress,
        )!
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth,
    );

    // Anchor the shader to the largest possible AI rectangle. As its left
    // edge moves, existing pixels keep the same color instead of stretching.
    final anchorLeft = available * RouteModeSwitcher._shrunkShare + gap;
    final shaderRect = Rect.fromLTWH(
      anchorLeft,
      0,
      size.width - anchorLeft,
      size.height,
    );
    canvas.drawRRect(
      aiRRect,
      Paint()
        ..shader = RouteBuilderDesignTokens.travelPlusGradient.createShader(
          shaderRect,
        ),
    );
    canvas.drawRRect(
      aiRRect,
      Paint()
        ..color = Color.lerp(
          RouteBuilderDesignTokens.deepBlue,
          RouteBuilderDesignTokens.primaryBlue,
          1 - progress,
        )!
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth,
    );
  }

  @override
  bool shouldRepaint(covariant _RouteModeSwitchPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.gap != gap ||
        oldDelegate.radius != radius ||
        oldDelegate.borderWidth != borderWidth;
  }
}

// ── City search ─────────────────────────────────────────────────────────────

class CitySearchField extends StatelessWidget {
  const CitySearchField({
    required this.px,
    required this.controller,
    required this.focusNode,
    required this.hasError,
    required this.onChanged,
    required this.onClear,
    super.key,
  });

  final RoutePx px;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasError;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(px(24));
    final borderColor = hasError
        ? const Color(0xFFE53935)
        : RouteBuilderDesignTokens.borderGray;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: px(48),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: RouteBuilderDesignTokens.fieldBackground,
              borderRadius: radius,
              border: Border.all(color: borderColor, width: px(1)),
            ),
            child: Row(
              children: [
                SizedBox(width: px(14)),
                CustomPaint(
                  size: Size(px(22), px(22)),
                  painter: _SearchIconPainter(
                    color: RouteBuilderDesignTokens.searchIcon,
                    stroke: px(2),
                  ),
                ),
                SizedBox(width: px(12)),
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    onChanged: onChanged,
                    textInputAction: TextInputAction.search,
                    style: RouteBuilderDesignTokens.rubik(
                      fontSize: px(14),
                      color: RouteBuilderDesignTokens.textPrimary,
                      height: 1.1,
                    ),
                    cursorColor: RouteBuilderDesignTokens.primaryBlue,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: 'Выберите стартовый город',
                      hintStyle: RouteBuilderDesignTokens.rubik(
                        fontSize: px(14),
                        color: RouteBuilderDesignTokens.textSecondary,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
                if (controller.text.isNotEmpty)
                  IconButton(
                    onPressed: onClear,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(
                      minWidth: px(36),
                      minHeight: px(36),
                    ),
                    icon: Icon(
                      Icons.close_rounded,
                      size: px(18),
                      color: RouteBuilderDesignTokens.textSecondary,
                    ),
                  )
                else
                  SizedBox(width: px(12)),
              ],
            ),
          ),
        ),
        if (hasError) ...[
          SizedBox(height: px(6)),
          Text(
            'Выберите стартовый город',
            style: RouteBuilderDesignTokens.rubik(
              fontSize: px(12),
              color: const Color(0xFFE53935),
              height: 1.1,
            ),
          ),
        ],
      ],
    );
  }
}

class _SearchIconPainter extends CustomPainter {
  _SearchIconPainter({required this.color, required this.stroke});

  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final r = size.shortestSide * 0.32;
    final center = Offset(size.width * 0.42, size.height * 0.42);
    canvas.drawCircle(center, r, paint);
    canvas.drawLine(
      Offset(center.dx + r * 0.72, center.dy + r * 0.72),
      Offset(size.width * 0.86, size.height * 0.86),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _SearchIconPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.stroke != stroke;
}

// ── City chips ──────────────────────────────────────────────────────────────

class CityQuickChips extends StatelessWidget {
  const CityQuickChips({
    required this.px,
    required this.cities,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final RoutePx px;
  final List<String> cities;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: px(38),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: px(16)),
            itemCount: cities.length,
            separatorBuilder: (_, _) => SizedBox(width: px(8.5)),
            itemBuilder: (context, index) {
              final city = cities[index];
              final isSelected = city == selected;
              return Semantics(
                button: true,
                selected: isSelected,
                label: city,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onSelected(city),
                    borderRadius: BorderRadius.circular(px(19)),
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    child: Ink(
                      height: px(38),
                      padding: EdgeInsets.symmetric(horizontal: px(18)),
                      decoration: BoxDecoration(
                        color: RouteBuilderDesignTokens.surface,
                        borderRadius: BorderRadius.circular(px(19)),
                        border: Border.all(
                          color: isSelected
                              ? RouteBuilderDesignTokens.primaryBlue
                              : RouteBuilderDesignTokens.chipBorder,
                          width: px(1),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          city,
                          style: RouteBuilderDesignTokens.rubik(
                            fontSize: px(13),
                            color: RouteBuilderDesignTokens.chipText,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(height: px(1)),
        Divider(
          height: px(1),
          thickness: px(1),
          color: RouteBuilderDesignTokens.lightBorder,
        ),
      ],
    );
  }
}

// ── Travel type ─────────────────────────────────────────────────────────────

class TravelTypeSelector extends StatelessWidget {
  const TravelTypeSelector({
    required this.px,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final RoutePx px;
  final RouteTripType? value;
  final ValueChanged<RouteTripType> onChanged;

  static const _entries = <(RouteTripType, String, String, String)>[
    (
      RouteTripType.romance,
      'Романтика',
      'Уютные места\nдля двоих',
      AppIconography.heart,
    ),
    (
      RouteTripType.rest,
      'Отдых',
      'Пляжи, море,\nкрасивая природа',
      AppIconography.map,
    ),
    (
      RouteTripType.adventure,
      'Приключения',
      'Тропы, виды,\nновые места',
      AppIconography.routes,
    ),
    (
      RouteTripType.active,
      'Активный',
      'Спорт, движение,\nадреналин',
      AppIconography.play,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: px(16)),
          child: Text(
            'Тип путешествия:',
            style: RouteBuilderDesignTokens.rubik(
              fontSize: px(18),
              weight: FontWeight.w700,
              color: RouteBuilderDesignTokens.textPrimary,
              height: 1.1,
            ),
          ),
        ),
        SizedBox(height: px(12)),
        SizedBox(
          height: px(124),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: px(16)),
            itemCount: _entries.length,
            separatorBuilder: (_, _) => SizedBox(width: px(8)),
            itemBuilder: (context, index) {
              final entry = _entries[index];
              final selected = value == entry.$1;
              return _TravelTypeCard(
                px: px,
                title: entry.$2,
                subtitle: entry.$3,
                iconAsset: entry.$4,
                selected: selected,
                onTap: () => onChanged(entry.$1),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TravelTypeCard extends StatelessWidget {
  const _TravelTypeCard({
    required this.px,
    required this.title,
    required this.subtitle,
    required this.iconAsset,
    required this.selected,
    required this.onTap,
  });

  final RoutePx px;
  final String title;
  final String subtitle;
  final String iconAsset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(px(12));
    return Semantics(
      excludeSemantics: true,
      button: true,
      selected: selected,
      label: title,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Ink(
            width: px(156),
            height: px(124),
            decoration: BoxDecoration(
              color: RouteBuilderDesignTokens.surface,
              borderRadius: radius,
              border: Border.all(
                color: selected
                    ? RouteBuilderDesignTokens.primaryBlue
                    : RouteBuilderDesignTokens.lightBorder,
                width: selected ? px(2) : px(1),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(px(8), px(12), px(8), px(8)),
              child: Column(
                children: [
                  Container(
                    width: px(40),
                    height: px(40),
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: RouteBuilderDesignTokens.primaryBlue,
                      shape: BoxShape.circle,
                    ),
                    child: AppAssetIcon(
                      iconAsset,
                      size: px(22),
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: px(10)),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RouteBuilderDesignTokens.rubik(
                      fontSize: px(15),
                      weight: FontWeight.w600,
                      color: RouteBuilderDesignTokens.textPrimary,
                      height: 1.0,
                    ),
                  ),
                  SizedBox(height: px(4)),
                  Expanded(
                    child: Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: RouteBuilderDesignTokens.rubik(
                        fontSize: px(12),
                        color: RouteBuilderDesignTokens.textSecondary,
                        height: 1.15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Duration ────────────────────────────────────────────────────────────────

class DurationSelector extends StatefulWidget {
  const DurationSelector({
    required this.px,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final RoutePx px;
  final RouteDurationOption value;
  final ValueChanged<RouteDurationOption> onChanged;

  static const _options = <(RouteDurationOption, String)>[
    (RouteDurationOption.d1_2, '1-2 дня'),
    (RouteDurationOption.d3_5, '3-5 дней'),
    (RouteDurationOption.d6_7, '6-7 дней'),
    (RouteDurationOption.d7plus, '>7 дней'),
  ];

  @override
  State<DurationSelector> createState() => _DurationSelectorState();
}

class _DurationSelectorState extends State<DurationSelector>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late double _fromPosition;
  late double _targetPosition;

  int _indexOf(RouteDurationOption value) =>
      DurationSelector._options.indexWhere((option) => option.$1 == value);

  double get _travelT => Curves.easeInOutCubic.transform(_controller.value);

  double get _position => lerpDouble(_fromPosition, _targetPosition, _travelT)!;

  @override
  void initState() {
    super.initState();
    final initial = _indexOf(widget.value).toDouble();
    _fromPosition = initial;
    _targetPosition = initial;
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.modeMorph,
      value: 1,
    );
  }

  @override
  void didUpdateWidget(covariant DurationSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _indexOf(widget.value).toDouble();
    if ((next - _targetPosition).abs() > 0.001) {
      _animateTo(next);
    }
  }

  void _select(int index) {
    final next = index.toDouble();
    if ((next - _targetPosition).abs() < 0.001) {
      return;
    }
    _animateTo(next);
    widget.onChanged(DurationSelector._options[index].$1);
  }

  void _animateTo(double next) {
    _fromPosition = _position;
    _targetPosition = next;
    final distance = (_targetPosition - _fromPosition).abs();
    _controller.duration = MediaQuery.disableAnimationsOf(context)
        ? AppMotion.reduced
        : Duration(milliseconds: (320 + 45 * distance).round());
    unawaited(_controller.forward(from: 0));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final px = widget.px;
    final radius = BorderRadius.circular(px(21));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Длительность маршрута:',
          style: RouteBuilderDesignTokens.rubik(
            fontSize: px(18),
            weight: FontWeight.w700,
            color: RouteBuilderDesignTokens.textPrimary,
            height: 1.1,
          ),
        ),
        SizedBox(height: px(11)),
        SizedBox(
          height: px(41),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: RouteBuilderDesignTokens.surface,
              borderRadius: radius,
              border: Border.all(
                color: RouteBuilderDesignTokens.lightBorder,
                width: px(1),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: px(4), horizontal: px(4)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(px(17)),
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final position = _position;
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        CustomPaint(
                          key: const ValueKey('duration-liquid-fill'),
                          painter: _DurationLiquidPainter(
                            position: position,
                            fromPosition: _fromPosition,
                            targetPosition: _targetPosition,
                            motionProgress: _controller.value,
                            color: RouteBuilderDesignTokens.primaryBlue,
                            innerRadius: px(4),
                          ),
                        ),
                        Row(
                          children: [
                            for (
                              var index = 0;
                              index < DurationSelector._options.length;
                              index++
                            )
                              Expanded(
                                child: _DurationSegment(
                                  px: px,
                                  index: index,
                                  label: DurationSelector._options[index].$2,
                                  selected:
                                      widget.value ==
                                      DurationSelector._options[index].$1,
                                  emphasis: (1 - (position - index).abs())
                                      .clamp(0.0, 1.0),
                                  onTap: () => _select(index),
                                ),
                              ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DurationSegment extends StatelessWidget {
  const _DurationSegment({
    required this.px,
    required this.index,
    required this.label,
    required this.selected,
    required this.emphasis,
    required this.onTap,
  });

  final RoutePx px;
  final int index;
  final String label;
  final bool selected;
  final double emphasis;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cap = Radius.circular(px(17));
    final inner = Radius.circular(px(4));
    final radius = BorderRadius.only(
      topLeft: index == 0 ? cap : inner,
      bottomLeft: index == 0 ? cap : inner,
      topRight: index == 3 ? cap : inner,
      bottomRight: index == 3 ? cap : inner,
    );
    return Semantics(
      excludeSemantics: true,
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: RouteBuilderDesignTokens.rubik(
                fontSize: px(14),
                weight: FontWeight.lerp(
                  FontWeight.w400,
                  FontWeight.w500,
                  emphasis,
                )!,
                color: Color.lerp(
                  RouteBuilderDesignTokens.chipText,
                  Colors.white,
                  emphasis,
                ),
                height: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DurationLiquidPainter extends CustomPainter {
  const _DurationLiquidPainter({
    required this.position,
    required this.fromPosition,
    required this.targetPosition,
    required this.motionProgress,
    required this.color,
    required this.innerRadius,
  });

  final double position;
  final double fromPosition;
  final double targetPosition;
  final double motionProgress;
  final Color color;
  final double innerRadius;

  @override
  void paint(Canvas canvas, Size size) {
    const segments = 4;
    final segmentWidth = size.width / segments;
    final centerX = (position + 0.5) * segmentWidth;
    final travelDistance = (targetPosition - fromPosition).abs() * segmentWidth;
    final flow = math.sin(math.pi * motionProgress.clamp(0.0, 1.0));
    final liquidStretch = travelDistance * 0.68 * flow;
    final desiredWidth = segmentWidth + liquidStretch;
    final left = math.max(0.0, centerX - desiredWidth / 2);
    final right = math.min(size.width, centerX + desiredWidth / 2);
    final rect = Rect.fromLTRB(left, 0, right, size.height);
    final cap = size.height / 2;
    final leftEdge = (1 - left / math.max(1.0, innerRadius * 2)).clamp(
      0.0,
      1.0,
    );
    final rightGap = size.width - right;
    final rightEdge = (1 - rightGap / math.max(1.0, innerRadius * 2)).clamp(
      0.0,
      1.0,
    );
    final leftRadius = lerpDouble(innerRadius, cap, leftEdge)!;
    final rightRadius = lerpDouble(innerRadius, cap, rightEdge)!;
    final rrect = RRect.fromRectAndCorners(
      rect,
      topLeft: Radius.circular(leftRadius),
      bottomLeft: Radius.circular(leftRadius),
      topRight: Radius.circular(rightRadius),
      bottomRight: Radius.circular(rightRadius),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant _DurationLiquidPainter oldDelegate) {
    return oldDelegate.position != position ||
        oldDelegate.fromPosition != fromPosition ||
        oldDelegate.targetPosition != targetPosition ||
        oldDelegate.motionProgress != motionProgress ||
        oldDelegate.color != color ||
        oldDelegate.innerRadius != innerRadius;
  }
}

// ── People ──────────────────────────────────────────────────────────────────

class PeopleCounter extends StatelessWidget {
  const PeopleCounter({
    required this.px,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final RoutePx px;
  final int value;
  final ValueChanged<int> onChanged;

  static String labelFor(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) {
      return '$n человек';
    }
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) {
      return '$n человека';
    }
    return '$n человек';
  }

  @override
  Widget build(BuildContext context) {
    final canInc = value < 10;
    final canDec = value > 1;
    final radius = BorderRadius.circular(px(24));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Количество людей:',
          style: RouteBuilderDesignTokens.rubik(
            fontSize: px(18),
            weight: FontWeight.w700,
            color: RouteBuilderDesignTokens.textPrimary,
            height: 1.1,
          ),
        ),
        SizedBox(height: px(12)),
        SizedBox(
          height: px(47),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: RouteBuilderDesignTokens.surface,
              borderRadius: radius,
              border: Border.all(
                color: RouteBuilderDesignTokens.lightBorder,
                width: px(1),
              ),
            ),
            child: Row(
              children: [
                SizedBox(width: px(5)),
                _StepperCircle(
                  px: px,
                  icon: Icons.remove,
                  enabled: canDec,
                  onTap: () => onChanged(value - 1),
                  semanticsLabel: 'Уменьшить количество людей',
                ),
                Expanded(
                  child: Text(
                    labelFor(value),
                    textAlign: TextAlign.center,
                    style: RouteBuilderDesignTokens.rubik(
                      fontSize: px(16),
                      weight: FontWeight.w500,
                      color: RouteBuilderDesignTokens.textPrimary,
                      height: 1.0,
                    ),
                  ),
                ),
                _StepperCircle(
                  px: px,
                  icon: Icons.add,
                  enabled: canInc,
                  onTap: () => onChanged(value + 1),
                  semanticsLabel: 'Увеличить количество людей',
                ),
                SizedBox(width: px(5)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StepperCircle extends StatelessWidget {
  const _StepperCircle({
    required this.px,
    required this.icon,
    required this.enabled,
    required this.onTap,
    required this.semanticsLabel,
  });

  final RoutePx px;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final border = RouteBuilderDesignTokens.borderGray.withValues(
      alpha: enabled ? 1 : 0.45,
    );
    final iconColor = RouteBuilderDesignTokens.borderGray.withValues(
      alpha: enabled ? 1 : 0.4,
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticsLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          customBorder: const CircleBorder(),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Ink(
            width: px(37),
            height: px(37),
            decoration: BoxDecoration(
              color: RouteBuilderDesignTokens.surface,
              shape: BoxShape.circle,
              border: Border.all(color: border, width: px(2)),
            ),
            child: Icon(icon, size: px(20), color: iconColor),
          ),
        ),
      ),
    );
  }
}

// ── Interests ───────────────────────────────────────────────────────────────

class InterestSelector extends StatelessWidget {
  const InterestSelector({
    required this.px,
    required this.options,
    required this.selected,
    required this.onToggle,
    super.key,
  });

  final RoutePx px;
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ваши интересы:',
          style: RouteBuilderDesignTokens.rubik(
            fontSize: px(18),
            weight: FontWeight.w700,
            color: RouteBuilderDesignTokens.textPrimary,
            height: 1.1,
          ),
        ),
        SizedBox(height: px(8)),
        Text(
          'Можно выбрать несколько вариантов',
          style: RouteBuilderDesignTokens.rubik(
            fontSize: px(12),
            color: RouteBuilderDesignTokens.textSecondary,
            height: 1.1,
          ),
        ),
        SizedBox(height: px(12)),
        Wrap(
          spacing: px(8),
          runSpacing: px(9),
          children: [
            for (final option in options)
              _InterestChip(
                px: px,
                label: option,
                selected: selected.contains(option),
                onTap: () => onToggle(option),
              ),
          ],
        ),
      ],
    );
  }
}

class _InterestChip extends StatelessWidget {
  const _InterestChip({
    required this.px,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final RoutePx px;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(px(8));
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Ink(
            height: px(38),
            padding: EdgeInsets.symmetric(horizontal: px(14)),
            decoration: BoxDecoration(
              color: selected
                  ? RouteBuilderDesignTokens.primaryBlue
                  : RouteBuilderDesignTokens.surface,
              borderRadius: radius,
              border: Border.all(
                color: selected
                    ? RouteBuilderDesignTokens.primaryBlue
                    : RouteBuilderDesignTokens.interestBorder,
                width: px(1),
              ),
            ),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: RouteBuilderDesignTokens.rubik(
                  fontSize: px(13),
                  color: selected
                      ? Colors.white
                      : RouteBuilderDesignTokens.chipText,
                  height: 1.0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Pace ────────────────────────────────────────────────────────────────────

class TravelPaceSelector extends StatelessWidget {
  const TravelPaceSelector({
    required this.px,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final RoutePx px;
  final RoutePace value;
  final ValueChanged<RoutePace> onChanged;

  static const _entries = <(RoutePace, String, String)>[
    (RoutePace.calm, 'Спокойный', 'Больше отдыха\nчем активности'),
    (RoutePace.moderate, 'Умеренный', 'Баланс отдыха\nи активности'),
    (RoutePace.active, 'Активный', 'Больше актива\nчем отдыха'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Темп путешествия:',
          style: RouteBuilderDesignTokens.rubik(
            fontSize: px(18),
            weight: FontWeight.w700,
            color: RouteBuilderDesignTokens.textPrimary,
            height: 1.1,
          ),
        ),
        SizedBox(height: px(12)),
        Row(
          children: [
            for (var i = 0; i < _entries.length; i++) ...[
              if (i > 0) SizedBox(width: px(10)),
              Expanded(
                child: _PaceCard(
                  px: px,
                  title: _entries[i].$2,
                  subtitle: _entries[i].$3,
                  selected: value == _entries[i].$1,
                  onTap: () => onChanged(_entries[i].$1),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _PaceCard extends StatelessWidget {
  const _PaceCard({
    required this.px,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final RoutePx px;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(px(8));
    return Semantics(
      button: true,
      selected: selected,
      label: title,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Ink(
            height: px(71),
            decoration: BoxDecoration(
              color: selected
                  ? RouteBuilderDesignTokens.selectedLightBlue
                  : RouteBuilderDesignTokens.surface,
              borderRadius: radius,
              border: Border.all(
                color: selected
                    ? RouteBuilderDesignTokens.primaryBlue
                    : RouteBuilderDesignTokens.borderGray,
                width: selected ? px(1.5) : px(1),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: px(6), vertical: px(8)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RouteBuilderDesignTokens.rubik(
                      fontSize: px(14),
                      weight: FontWeight.w500,
                      color: selected
                          ? RouteBuilderDesignTokens.primaryBlue
                          : RouteBuilderDesignTokens.textPrimary,
                      height: 1.0,
                    ),
                  ),
                  SizedBox(height: px(4)),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: RouteBuilderDesignTokens.rubik(
                      fontSize: px(10.75),
                      color: RouteBuilderDesignTokens.textSecondary,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Action buttons ──────────────────────────────────────────────────────────

class RouteActionButtons extends StatelessWidget {
  const RouteActionButtons({
    required this.px,
    required this.attemptsLeft,
    required this.matching,
    required this.onMatch,
    required this.onAi,
    super.key,
  });

  final RoutePx px;
  final int attemptsLeft;
  final bool matching;
  final VoidCallback onMatch;
  final VoidCallback onAi;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PrimaryMatchButton(px: px, matching: matching, onPressed: onMatch),
        SizedBox(height: px(8)),
        _AiMatchButton(px: px, attemptsLeft: attemptsLeft, onPressed: onAi),
      ],
    );
  }
}

class _PrimaryMatchButton extends StatelessWidget {
  const _PrimaryMatchButton({
    required this.px,
    required this.matching,
    required this.onPressed,
  });

  final RoutePx px;
  final bool matching;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(px(28));
    return Semantics(
      button: true,
      label: 'Подобрать маршрут',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: matching ? null : onPressed,
          borderRadius: radius,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Ink(
            height: px(56),
            decoration: BoxDecoration(
              color: RouteBuilderDesignTokens.textPrimary,
              borderRadius: radius,
            ),
            child: Center(
              child: matching
                  ? SizedBox(
                      width: px(22),
                      height: px(22),
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Подобрать маршрут',
                      style: RouteBuilderDesignTokens.rubik(
                        fontSize: px(17),
                        color: Colors.white,
                        height: 1.0,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AiMatchButton extends StatelessWidget {
  const _AiMatchButton({
    required this.px,
    required this.attemptsLeft,
    required this.onPressed,
  });

  final RoutePx px;
  final int attemptsLeft;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(px(28));
    return Semantics(
      button: true,
      label: 'Собрать маршрут с ИИ',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: radius,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Ink(
            width: double.infinity,
            height: px(56),
            decoration: BoxDecoration(
              gradient: RouteBuilderDesignTokens.travelPlusGradient,
              borderRadius: radius,
              border: Border.all(
                color: RouteBuilderDesignTokens.deepBlue,
                width: px(2),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Собрать маршрут с ИИ',
                  textAlign: TextAlign.center,
                  style: RouteBuilderDesignTokens.rubik(
                    fontSize: px(17),
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
                SizedBox(height: px(3)),
                Text(
                  'Осталось $attemptsLeft попытки без подписки',
                  textAlign: TextAlign.center,
                  style: RouteBuilderDesignTokens.rubik(
                    fontSize: px(11.75),
                    color: RouteBuilderDesignTokens.aiCaption,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── AI chat ─────────────────────────────────────────────────────────────────

class RouteAiChatView extends StatelessWidget {
  const RouteAiChatView({
    required this.header,
    required this.px,
    required this.messages,
    required this.scrollController,
    required this.composerController,
    required this.composerFocus,
    required this.typing,
    required this.canSend,
    required this.onChanged,
    required this.onSend,
    required this.bottomInset,
    super.key,
  });

  final Widget header;
  final RoutePx px;
  final List<RouteChatMessage> messages;
  final ScrollController scrollController;
  final TextEditingController composerController;
  final FocusNode composerFocus;
  final bool typing;
  final bool canSend;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final itemCount = 2 + messages.length + (typing ? 1 : 0);
    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: ListView.builder(
              key: const ValueKey('route-match-ai-scroll'),
              controller: scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.only(bottom: px(12)),
              itemCount: itemCount,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return header;
                }
                if (index == 1) {
                  return Padding(
                    padding: EdgeInsets.only(top: px(15)),
                    child: Divider(
                      height: px(1),
                      thickness: px(1),
                      color: RouteBuilderDesignTokens.divider,
                    ),
                  );
                }
                final messageIndex = index - 2;
                if (typing && messageIndex == messages.length) {
                  return Padding(
                    padding: EdgeInsets.fromLTRB(px(16), px(8), px(16), 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Тревел Агент печатает…',
                        style: RouteBuilderDesignTokens.rubik(
                          fontSize: px(13),
                          color: RouteBuilderDesignTokens.textSecondary,
                        ),
                      ),
                    ),
                  );
                }
                final message = messages[messageIndex];
                final topGap = messageIndex == 0 ? px(12) : px(15);
                return Padding(
                  padding: EdgeInsets.fromLTRB(px(16), topGap, px(16), 0),
                  child: message.fromAgent
                      ? AgentMessageBubble(px: px, message: message)
                      : UserMessageBubble(px: px, message: message),
                );
              },
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            px(16),
            px(8),
            px(16),
            math.max(px(12), bottomInset) + keyboard,
          ),
          child: ChatComposer(
            px: px,
            controller: composerController,
            focusNode: composerFocus,
            canSend: canSend && !typing,
            onChanged: onChanged,
            onSend: onSend,
          ),
        ),
      ],
    );
  }
}

class AgentMessageBubble extends StatelessWidget {
  const AgentMessageBubble({
    required this.px,
    required this.message,
    super.key,
  });

  final RoutePx px;
  final RouteChatMessage message;

  @override
  Widget build(BuildContext context) {
    final outerRadius = BorderRadius.circular(px(16));
    final innerRadius = BorderRadius.circular(px(14));
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: px(265)),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: outerRadius,
            gradient: const SweepGradient(
              center: Alignment.center,
              colors: RouteBuilderDesignTokens.agentBorderGradient,
              stops: [0.0, 0.28, 0.62, 1.0],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(px(2)),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: RouteBuilderDesignTokens.surface,
                borderRadius: innerRadius,
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(px(12), px(12), px(12), px(10)),
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Тревел Агент',
                          style: RouteBuilderDesignTokens.rubik(
                            fontSize: px(14),
                            color: RouteBuilderDesignTokens.deepBlue,
                            height: 1.1,
                          ),
                        ),
                        SizedBox(height: px(4)),
                        Padding(
                          padding: EdgeInsets.only(bottom: px(14)),
                          child: Text(
                            message.text,
                            style: RouteBuilderDesignTokens.rubik(
                              fontSize: px(16),
                              color: RouteBuilderDesignTokens.textPrimary,
                              height: 1.08,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Text(
                        message.time,
                        style: RouteBuilderDesignTokens.rubik(
                          fontSize: px(12),
                          color: RouteBuilderDesignTokens.agentTimestamp,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class UserMessageBubble extends StatelessWidget {
  const UserMessageBubble({required this.px, required this.message, super.key});

  final RoutePx px;
  final RouteChatMessage message;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(px(16));
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: px(265)),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: RouteBuilderDesignTokens.primaryBlue,
            borderRadius: radius,
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(px(12), px(14), px(12), px(10)),
            child: Stack(
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: px(16)),
                  child: Text(
                    message.text,
                    style: RouteBuilderDesignTokens.rubik(
                      fontSize: px(16),
                      color: Colors.white,
                      height: 1.08,
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Text(
                    message.time,
                    style: RouteBuilderDesignTokens.rubik(
                      fontSize: px(12),
                      color: Colors.white.withValues(alpha: 0.85),
                      height: 1.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ChatComposer extends StatelessWidget {
  const ChatComposer({
    required this.px,
    required this.controller,
    required this.focusNode,
    required this.canSend,
    required this.onChanged,
    required this.onSend,
    super.key,
  });

  final RoutePx px;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool canSend;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final fieldRadius = BorderRadius.circular(px(24));
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: px(48),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: RouteBuilderDesignTokens.fieldBackground,
                borderRadius: fieldRadius,
                border: Border.all(
                  color: RouteBuilderDesignTokens.borderGray,
                  width: px(1),
                ),
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: onChanged,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) {
                  if (canSend) {
                    onSend();
                  }
                },
                style: RouteBuilderDesignTokens.rubik(
                  fontSize: px(15.5),
                  color: RouteBuilderDesignTokens.textPrimary,
                  height: 1.1,
                ),
                cursorColor: RouteBuilderDesignTokens.primaryBlue,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: px(16),
                    vertical: px(14),
                  ),
                  hintText: 'Сообщение',
                  hintStyle: RouteBuilderDesignTokens.rubik(
                    fontSize: px(15.5),
                    color: RouteBuilderDesignTokens.textSecondary,
                    height: 1.1,
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: px(8)),
        Semantics(
          button: true,
          enabled: canSend,
          label: 'Отправить сообщение',
          child: Opacity(
            opacity: canSend ? 1 : 0.45,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: canSend ? onSend : null,
                customBorder: const CircleBorder(),
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                child: Ink(
                  width: px(48),
                  height: px(48),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RouteBuilderDesignTokens.actionLinearGradient,
                    border: Border.all(
                      color: RouteBuilderDesignTokens.deepBlue,
                      width: px(1.75),
                    ),
                  ),
                  child: Center(
                    child: CustomPaint(
                      size: Size(px(22), px(22)),
                      painter: _PaperPlanePainter(stroke: px(1.7)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PaperPlanePainter extends CustomPainter {
  _PaperPlanePainter({required this.stroke});

  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * 0.08, size.height * 0.55)
      ..lineTo(size.width * 0.92, size.height * 0.18)
      ..lineTo(size.width * 0.42, size.height * 0.88)
      ..lineTo(size.width * 0.38, size.height * 0.58)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawLine(
      Offset(size.width * 0.38, size.height * 0.58),
      Offset(size.width * 0.92, size.height * 0.18),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _PaperPlanePainter oldDelegate) =>
      oldDelegate.stroke != stroke;
}
