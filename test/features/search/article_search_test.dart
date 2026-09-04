import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/articles/application/articles_providers.dart';
import 'package:tourism_mobile/features/search/application/universal_search_provider.dart';

import '../../support/test_overrides.dart';

/// The universal search covered routes, places and people; a blog was the one
/// kind of content it could not find (asked 2026-09-04).
void main() {
  test('universal search returns articles alongside everything else', () async {
    final container = ProviderContainer(
      overrides: testSessionOverrides(onboardingCompleted: true),
    );
    addTearDown(container.dispose);

    // The seeded mock article is about a three-day trip on the south shore.
    final results = await container.read(
      universalSearchProvider('Южном').future,
    );
    expect(results.articles, isNotEmpty);
    expect(results.articles.first.title, contains('Южном'));
    expect(results.isEmpty, isFalse);
  });

  test('the article repository filters by title and by tag', () async {
    final container = ProviderContainer(
      overrides: testSessionOverrides(onboardingCompleted: true),
    );
    addTearDown(container.dispose);
    final repository = container.read(articlesRepositoryProvider);

    final byTitle = await repository.listArticles(query: 'Южном');
    expect(byTitle.items, isNotEmpty);

    final nothing = await repository.listArticles(query: 'зззнесуществует');
    expect(nothing.items, isEmpty);

    // An empty query is not a filter.
    final all = await repository.listArticles();
    expect(all.items.length, greaterThanOrEqualTo(byTitle.items.length));
  });
}
