import 'dart:async';

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
    this.sheetTitle,
    super.key,
  });

  final RoutePx px;
  final List<Map<String, String>> actions;
  final void Function(String id, String label) onAction;
  final ChatActionsLayout layout;
  final String? sheetTitle;

  Future<void> _openSheet(
    BuildContext context,
    List<Map<String, String>> visible,
  ) async {
    final selected = await showModalBottomSheet<Map<String, String>>(
      context: context,
      backgroundColor: RouteBuilderDesignTokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(px(20))),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: px(12)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(px(20), px(4), px(20), px(12)),
                  child: Text(
                    sheetTitle ?? 'Выбрать',
                    style: RouteBuilderDesignTokens.rubik(
                      fontSize: px(16),
                      weight: FontWeight.w600,
                      color: RouteBuilderDesignTokens.textPrimary,
                    ),
                  ),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => Divider(
                      height: px(1),
                      color: RouteBuilderDesignTokens.deepBlue.withValues(
                        alpha: 0.08,
                      ),
                    ),
                    itemBuilder: (_, index) {
                      final item = visible[index];
                      return ListTile(
                        title: Text(
                          item['label']!,
                          style: RouteBuilderDesignTokens.rubik(
                            fontSize: px(15),
                            color: RouteBuilderDesignTokens.textPrimary,
                          ),
                        ),
                        onTap: () => Navigator.of(sheetContext).pop(item),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected != null) {
      onAction(selected['id']!, selected['label']!);
    }
  }

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

    if (layout == ChatActionsLayout.sheet) {
      return _StackActionButton(
        px: px,
        label: sheetTitle ?? 'Выбрать',
        icon: Icons.expand_more,
        onPressed: () => unawaited(_openSheet(context, visible)),
      );
    }

    if (layout == ChatActionsLayout.stack) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < visible.length; i++) ...[
            // 34 px pitch measured off the design export: 28 px pill + 6 gap.
            if (i > 0) SizedBox(height: px(6)),
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
                fontSize: px(12),
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
    this.icon,
  });

  final RoutePx px;
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final textStyle = RouteBuilderDesignTokens.rubik(
      fontSize: px(12),
      weight: FontWeight.w400,
      height: 1.1,
    );
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: RouteBuilderDesignTokens.deepBlue,
        side: BorderSide(
          color: RouteBuilderDesignTokens.deepBlue.withValues(alpha: 0.35),
        ),
        minimumSize: Size.fromHeight(px(28)),
        padding: EdgeInsets.symmetric(horizontal: px(10)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(px(8)),
        ),
        textStyle: textStyle,
      ),
      child: icon == null
          ? Text(label)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label),
                SizedBox(width: px(2)),
                Icon(icon, size: px(16)),
              ],
            ),
    );
  }
}
