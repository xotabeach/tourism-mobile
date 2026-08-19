import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/routes/data/route_reviews_repository.dart';

void main() {
  test('route review parses ordered API photo metadata', () {
    final review = RouteReview.fromJson({
      'id': 'review-1',
      'route_id': 'route-1',
      'author_user_id': 'user-1',
      'author_display_name': 'Никита',
      'author_rank_title': 'Эксперт',
      'body': 'Отзыв с фотографиями',
      'rating': 5,
      'status': 'published',
      'created_at': '2026-08-19T10:00:00Z',
      'media': [
        {
          'id': 'photo-1',
          'url': '/media/reviews/review-1/photo.webp',
          'width': 1200,
          'height': 800,
          'sort_order': 0,
        },
      ],
    });

    expect(review.media, hasLength(1));
    expect(review.media.single.id, 'photo-1');
    expect(review.media.single.width, 1200);
    expect(review.media.single.sortOrder, 0);
  });

  test('route review parses persistent reply context', () {
    final review = RouteReview.fromJson({
      'id': 'reply-1',
      'route_id': 'route-1',
      'author_user_id': 'user-2',
      'body': 'Согласен, особенно на закате',
      'rating': 5,
      'status': 'published',
      'created_at': '2026-08-19T10:00:00Z',
      'reply_to': {
        'review_id': 'review-1',
        'author_user_id': 'user-1',
        'author_display_name': 'Никита',
        'body': 'На смотровой отличные виды',
      },
    });

    expect(review.replyTo?.reviewId, 'review-1');
    expect(review.replyTo?.authorDisplayName, 'Никита');
    expect(review.replyTo?.body, 'На смотровой отличные виды');
  });
}
