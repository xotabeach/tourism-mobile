import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_motion.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_glass.dart';

/// Media gallery on top of the route details screen.
///
/// Collapsed it shows a single cover; a swipe up (or a tap) grows it past half
/// of the screen so the whole photo is visible and the media can be paged
/// horizontally.
class RouteMediaHeader extends StatefulWidget {
  const RouteMediaHeader({
    required this.images,
    required this.expanded,
    required this.onExpandedChanged,
    required this.onStartRoute,
    this.actions = const [],
    super.key,
  });

  static const double collapsedHeight = 300;
  static const double expandedHeightFactor = 0.66;

  final List<ImageProvider> images;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;
  final VoidCallback onStartRoute;
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

  void _toggle() => widget.onExpandedChanged(!widget.expanded);

  void _handleDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -90) {
      widget.onExpandedChanged(true);
    } else if (velocity > 90) {
      widget.onExpandedChanged(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final reduceMotion = media.disableAnimations;
    final expandedHeight =
        media.size.height * RouteMediaHeader.expandedHeightFactor;
    final height = widget.expanded
        ? expandedHeight
        : RouteMediaHeader.collapsedHeight;

    return Semantics(
      label: widget.expanded
          ? 'Галерея маршрута раскрыта'
          : 'Обложка маршрута, свайп вверх раскрывает галерею',
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggle,
        onVerticalDragEnd: _handleDragEnd,
        child: AnimatedContainer(
          duration: reduceMotion ? AppMotion.reduced : AppMotion.emphasized,
          curve: AppMotion.emphasizedCurve,
          height: height,
          color: AppColors.imageScrim,
          child: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: _controller,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (value) => setState(() => _page = value),
                itemCount: widget.images.length,
                itemBuilder: (context, index) =>
                    Image(image: widget.images[index], fit: BoxFit.cover),
              ),
              const IgnorePointer(child: _HeaderScrim()),
              Positioned(
                top: media.padding.top + 8,
                left: 12,
                right: 12,
                child: Row(children: widget.actions),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 34,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PageDots(count: widget.images.length, active: _page),
                    const SizedBox(height: 14),
                    _StartRouteButton(onPressed: widget.onStartRoute),
                  ],
                ),
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

class _StartRouteButton extends StatelessWidget {
  const _StartRouteButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: AppGlassSurface(
        borderRadius: AppRadii.capsule,
        blur: 12,
        fillColor: Colors.white.withValues(alpha: 0.22),
        borderColor: Colors.white.withValues(alpha: 0.34),
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
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
