import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_spacing.dart';
import 'package:tourism_mobile/features/routes/presentation/route_details_screen.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_media_header.dart';

/// [RouteDetailsScreen] for callers that live outside the tab shell.
///
/// `/routes/:id` is declared inside the "Маршруты" branch, so a push into it
/// from a root-level screen (the article) trips Navigator's duplicate-page-key
/// assertion and leaves a blank page. This variant is a root-navigator route,
/// which keeps the pushing screen underneath — back returns to the article
/// rather than dumping the reader on the routes tab.
///
/// The shell normally supplies this screen's chrome — the collapsed floating
/// nav and the «Пройти маршрут» CTA. Off the shell there is no nav to collapse
/// (a tab bar would be wrong above a pushed detail page anyway), but the CTA is
/// a real action and is rebuilt here from the same [RouteStartButton] the shell
/// uses, over the same bottom scrim, so nothing is lost but the tab chrome.
class StandaloneRouteDetailsScreen extends StatelessWidget {
  const StandaloneRouteDetailsScreen({required this.routeId, super.key});

  final String routeId;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: AppColors.pageSurface,
      body: Stack(
        fit: StackFit.expand,
        children: [
          RouteDetailsScreen(routeId: routeId),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: bottomInset + 156,
            child: const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x00FFFFFF),
                      Color(0xF2FFFFFF),
                      AppColors.elevatedSurface,
                    ],
                    stops: [0, 0.46, 1],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: AppSpacing.floatingNavInset,
            right: AppSpacing.floatingNavInset,
            bottom: bottomInset > 0 ? bottomInset : AppSpacing.sm,
            child: RouteStartButton(
              onPressed: () =>
                  unawaited(context.push('/routes/$routeId/execution')),
            ),
          ),
        ],
      ),
    );
  }
}
