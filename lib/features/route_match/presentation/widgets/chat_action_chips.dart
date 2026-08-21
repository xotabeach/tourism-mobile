import 'package:flutter/material.dart';

import 'package:tourism_mobile/features/route_match/presentation/route_builder_design_tokens.dart';

typedef RoutePx = double Function(double);

/// Quick-reply chips under an assistant message (parameter / confirm actions).
class ChatActionChips extends StatelessWidget {
  const ChatActionChips({
    required this.px,
    required this.actions,
    required this.onAction,
    super.key,
  });

  final RoutePx px;
  final List<Map<String, String>> actions;
  final void Function(String id, String label) onAction;

  @override
  Widget build(BuildContext context) {
    final visible = actions
        .where(
          (item) =>
              (item['id'] ?? '').isNotEmpty && (item['label'] ?? '').isNotEmpty,
        )
        .toList(growable: false);
    if (visible.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: px(8),
      runSpacing: px(8),
      children: [
        for (final action in visible)
          ActionChip(
            label: Text(
              action['label']!,
              style: RouteBuilderDesignTokens.rubik(
                fontSize: px(13),
                color: RouteBuilderDesignTokens.deepBlue,
                height: 1.1,
              ),
            ),
            backgroundColor: RouteBuilderDesignTokens.surface,
            side: BorderSide(
              color: RouteBuilderDesignTokens.deepBlue.withValues(alpha: 0.35),
            ),
            onPressed: () => onAction(action['id']!, action['label']!),
          ),
      ],
    );
  }
}
