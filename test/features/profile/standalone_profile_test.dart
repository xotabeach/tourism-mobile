import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/features/home/presentation/home_screen.dart';
import 'package:tourism_mobile/features/profile/presentation/profile_screen.dart';
import 'package:tourism_mobile/routing/app_router.dart';

import '../../support/test_overrides.dart';

void main() {
  // FRONTEND-99: a companion's profile opened from a group sits on the root
  // navigator, outside the tabs' Scaffold. Without a Material above it every
  // text took Flutter's yellow-underlined fallback style.
  testWidgets('a profile opened outside the tabs has a Material above it', (
    tester,
  ) async {
    await pumpTourismAppAtHome(tester);
    unawaited(
      GoRouter.of(tester.element(find.byType(HomeScreen))).pushNamed(
        AppRouteNames.userProfileStandalone,
        pathParameters: {'userId': 'someone-else'},
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    final profile = find.byType(ProfileScreen);
    expect(profile, findsOneWidget);
    expect(
      find.ancestor(of: profile, matching: find.byType(Material)),
      findsWidgets,
    );
    final style = DefaultTextStyle.of(tester.element(profile)).style;
    expect(style.decoration, isNot(TextDecoration.underline));
  });
}
