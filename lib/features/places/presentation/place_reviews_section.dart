import 'package:flutter/material.dart';

import 'package:tourism_mobile/features/reviews/presentation/entity_reviews_section.dart';

class PlaceReviewsSection extends StatelessWidget {
  const PlaceReviewsSection({required this.placeId, super.key});

  final String placeId;

  @override
  Widget build(BuildContext context) {
    return EntityReviewsSection(
      entityId: placeId,
      kind: ReviewEntityKind.place,
    );
  }
}
