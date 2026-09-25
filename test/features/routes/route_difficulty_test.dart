import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/route_execution/data/difficulty_feedback_api.dart';
import 'package:tourism_mobile/features/route_execution/presentation/route_execution_summary_screen.dart';
import 'package:tourism_mobile/features/route_publish/domain/publish_route.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/difficulty_breakdown_sheet.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_hero_card.dart';

RouteDetail _route({
  int? level,
  int? auto,
  String source = 'auto',
  String? word,
  Map<String, dynamic>? breakdown,
}) => RouteDetail.fromJson({
  'id': 'r',
  'name': 'Демерджи',
  'slug': 'r',
  'short_description': null,
  'stops_count': 3,
  'difficulty': word,
  'difficulty_level': level,
  'difficulty_auto': auto,
  'difficulty_source': source,
  'description': null,
  'accessibility': {'difficulty': ?breakdown},
});

const _breakdown = {
  'level': 4,
  'walk_level': 4,
  'drive_level': 1,
  'confidence': 'high',
  'reasons': [
    {'code': 'trail', 'grade': 'T3', 'meters': 400},
    {
      'code': 'walk_effort',
      'effort_km': 16.5,
      'km': 9.0,
      'ascent_m': 500,
      'descent_m': 500,
    },
    {'code': 'drive_hours', 'hours': 0.4},
  ],
};

void main() {
  test('level wins over the old word, which still works alone', () {
    expect(_route(level: 1, word: 'easy').shownDifficulty, 1);
    expect(_route(word: 'extreme').shownDifficulty, 5);
    expect(routeDifficultyText(_route()), 'Маршрут');
    expect(routeDifficultyText(_route(level: 1)), 'Прогулка');
  });

  test('breakdown reasons read as sentences', () {
    final breakdown = _route(breakdown: _breakdown).difficultyBreakdown!;
    expect(breakdown.level, 4);
    expect(breakdown.approximate, isFalse);
    expect(breakdown.reasons.map((reason) => reason.text), [
      'Горная тропа T3: 0,4 км',
      'Пешком 9 км, набор 500 м (нагрузка как 16,5 км по ровному)',
      'За рулём 0,4 ч',
    ]);
    expect(const DifficultyReason('mystery', {}).text, isNull);
  });

  test('whose rating is shown, when it differs from the estimate', () {
    expect(
      difficultySourceNote(_route(level: 3, auto: 3, source: 'author')),
      isNull,
    );
    expect(
      difficultySourceNote(_route(level: 5, auto: 3, source: 'author')),
      'По оценке автора, по расчёту: 3 из 5',
    );
    expect(
      difficultySourceNote(_route(level: 1, auto: 4, source: 'editorial')),
      'По оценке редакции, по расчёту: 4 из 5',
    );
  });

  test('draft on «Авто» shows the estimate and limits own ratings', () {
    const auto = RouteDraft(difficulty: 3, difficultyEstimate: 4);
    expect(auto.shownDifficulty, 4);
    expect(auto.lowestDifficulty, 3);
    final own = auto.copyWith(difficulty: 5, difficultyManual: true);
    expect(own.shownDifficulty, 5);
    final restored = RouteDraft.fromJson(own.toJson());
    expect(restored.difficultyManual, isTrue);
    expect(restored.difficultyEstimate, 4);
    // A draft saved before spec 17 had no «Авто»: its 3 was a default.
    expect(RouteDraft.fromJson({'difficulty': 3}).difficultyManual, isFalse);
    expect(auto.sameContentAs(own), isFalse);
  });

  testWidgets('breakdown sheet lists reasons and the author note', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DifficultyBreakdownSheet(
            route: _route(
              level: 5,
              auto: 4,
              source: 'author',
              breakdown: _breakdown,
            ),
          ),
        ),
      ),
    );
    expect(find.text('Сложность: 5 из 5 · Экстрим'), findsOneWidget);
    expect(find.text('По оценке автора, по расчёту: 4 из 5'), findsOneWidget);
    expect(find.text('Горная тропа T3: 0,4 км'), findsOneWidget);
  });

  testWidgets('one tap sends the answer after a run', (tester) async {
    final sent = <(String, DifficultyFeedback)>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sendDifficultyFeedbackProvider.overrideWithValue(
            (id, answer) async => sent.add((id, answer)),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: DifficultyFeedbackCard(executionId: 'run-1')),
        ),
      ),
    );
    expect(find.text('Как вам сложность маршрута?'), findsOneWidget);
    await tester.tap(find.text('Сложнее'));
    await tester.pump();
    expect(sent, [('run-1', DifficultyFeedback.harder)]);
    expect(
      find.text('Спасибо, это поможет точнее оценивать маршруты'),
      findsOneWidget,
    );
  });
}
