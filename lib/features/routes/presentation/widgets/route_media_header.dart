import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_motion.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_glass.dart';

/// Media gallery on top of the route details screen.
///
/// A tap toggles expansion; page scrolling remains independent.
class RouteMediaHeader extends StatefulWidget {
  const RouteMediaHeader({
    required this.images,
    required this.expansionProgress,
    required this.onToggle,
    this.heroTag,
    this.actions = const [],
    super.key,
  });

  static const double collapsedHeight = 300;
  static const double expandedHeightFactor = 0.66;

  final List<ImageProvider> images;
  final double expansionProgress;
  final VoidCallback onToggle;
  final Object? heroTag;
  final List<Widget> actions;

  @override
  State<RouteMediaHeader> createState() => _RouteMediaHeaderState();
}

class _RouteMediaHeaderState extends State<RouteMediaHeader> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final expandedHeight =
        media.size.height * RouteMediaHeader.expandedHeightFactor;
    final progress = widget.expansionProgress.clamp(0.0, 1.0);
    final height =
        RouteMediaHeader.collapsedHeight +
        (expandedHeight - RouteMediaHeader.collapsedHeight) * progress;
    final expanded = progress > 0.5;

    return Semantics(
      label: expanded
          ? 'Галерея маршрута раскрыта'
          : 'Обложка маршрута, нажмите, чтобы раскрыть галерею',
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onToggle,
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: _controller,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (value) => setState(() => _page = value),
                itemCount: widget.images.length,
                itemBuilder: (context, index) {
                  final image = Image(
                    image: widget.images[index],
                    fit: BoxFit.cover,
                  );
                  if (index == 0 && widget.heroTag != null) {
                    return Hero(
                      tag: widget.heroTag!,
                      transitionOnUserGestures: true,
                      child: image,
                    );
                  }
                  return image;
                },
              ),
              const IgnorePointer(child: _HeaderScrim()),
              Positioned(
                top: media.padding.top + 8,
                left: 12,
                right: 12,
                child: Row(children: widget.actions),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 28,
                child: _PageDots(count: widget.images.length, active: _page),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderScrim extends StatelessWidget {
  const _HeaderScrim();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x59000000), Color(0x00000000), Color(0x4D000000)],
          stops: [0, 0.38, 1],
        ),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    if (count < 2) {
      return const SizedBox(height: 10);
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var index = 0; index < count; index++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: AnimatedContainer(
              duration: AppMotion.fast,
              width: index == active ? 10 : 8,
              height: index == active ? 10 : 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(
                  alpha: index == active ? 1 : 0.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class RouteStartButton extends StatelessWidget {
  const RouteStartButton({
    required this.onPressed,
    this.visibility = 1,
    this.morphProgress = 0,
    super.key,
  });

  final VoidCallback onPressed;
  final double visibility;
  final double morphProgress;

  @override
  Widget build(BuildContext context) {
    final progress = visibility.clamp(0.0, 1.0);
    final morph = morphProgress.clamp(0.0, 1.0);
    final liquidStretch = math.sin(math.pi * morph);
    return Transform.scale(
      alignment: morph > 0.5 ? Alignment.centerLeft : Alignment.bottomCenter,
      scaleX: 1 + 0.025 * liquidStretch,
      scaleY: 1 - 0.045 * liquidStretch,
      child: SizedBox(
        height: 56,
        width: double.infinity,
        child: AppGlassSurface(
          borderRadius: AppRadii.capsule,
          blur: 20 * progress,
          fillColor: AppColors.primaryInk.withValues(alpha: 0.9 * progress),
          borderColor: Colors.white.withValues(alpha: 0.42 * progress),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16 * progress),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
          child: IgnorePointer(
            ignoring: progress < 0.99,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadii.capsule),
                onTap: onPressed,
                child: Center(
                  child: Text(
                    'Пройти маршрут',
                    style: AppTypography.button.copyWith(
                      fontSize: 17,
                      color: Colors.white.withValues(alpha: progress),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
