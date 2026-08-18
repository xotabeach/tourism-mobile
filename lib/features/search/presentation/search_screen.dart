import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/features/search/presentation/in_place_search.dart';

class SearchScreen extends ConsumerWidget {
  const SearchScreen({super.key});

  static const routePath = '/search';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const ColoredBox(
      color: AppColors.pageSurface,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SingleChildScrollView(child: InPlaceSearchBody(query: '')),
        ),
      ),
    );
  }
}
