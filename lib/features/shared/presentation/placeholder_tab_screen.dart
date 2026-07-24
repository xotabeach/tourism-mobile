import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/theme/app_colors.dart';

/// Placeholder screens for tabs whose domain work lands in later phases.
class PlaceholderTabScreen extends StatelessWidget {
  const PlaceholderTabScreen({
    required this.title,
    required this.message,
    super.key,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return ColoredBox(
      color: AppColors.mist,
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, topInset + 24, 24, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            Text(message, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
