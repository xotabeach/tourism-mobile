import 'package:flutter/material.dart';

import 'package:tourism_mobile/features/route_match/domain/route_match_models.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_builder_design_tokens.dart';

typedef RoutePx = double Function(double);

/// Quick-reply chips under an assistant message (parameter / confirm actions).
class ChatActionChips extends StatelessWidget {
  const ChatActionChips({
    required this.px,
    required this.actions,
    required this.onAction,
    this.layout = ChatActionsLayout.wrap,
    super.key,
  });

  final RoutePx px;
  final List<Map<String, String>> actions;
  final void Function(String id, String label) onAction;
  final ChatActionsLayout layout;

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

    if (layout == ChatActionsLayout.stack) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < visible.length; i++) ...[
            if (i > 0) SizedBox(height: px(8)),
            _StackActionButton(
              px: px,
              label: visible[i]['label']!,
              onPressed: () =>
                  onAction(visible[i]['id']!, visible[i]['label']!),
            ),
          ],
        ],
      );
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

class _StackActionButton extends StatelessWidget {
  const _StackActionButton({
    required this.px,
    required this.label,
    required this.onPressed,
  });

  final RoutePx px;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: RouteBuilderDesignTokens.deepBlue,
        side: BorderSide(
          color: RouteBuilderDesignTokens.deepBlue.withValues(alpha: 0.35),
        ),
        minimumSize: Size.fromHeight(px(42)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(px(10)),
        ),
        textStyle: RouteBuilderDesignTokens.rubik(
          fontSize: px(14),
          weight: FontWeight.w500,
          height: 1.1,
        ),
      ),
      child: Text(label),
    );
  }
}
