import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/components/app_notice.dart';
import 'package:tourism_mobile/features/companions/application/companions_providers.dart';
import 'package:tourism_mobile/features/companions/presentation/companion_sheets.dart';
import 'package:tourism_mobile/features/profile/application/profile_providers.dart';

/// «Заблокировать» at the end of someone else's profile (FRONTEND-63, spec
/// 11b D15): no invitations and no shared groups, both ways.
class BlockPersonButton extends ConsumerStatefulWidget {
  const BlockPersonButton({
    required this.userId,
    required this.displayName,
    required this.blocked,
    super.key,
  });

  final String userId;
  final String displayName;
  final bool blocked;

  @override
  ConsumerState<BlockPersonButton> createState() => _BlockPersonButtonState();
}

class _BlockPersonButtonState extends ConsumerState<BlockPersonButton> {
  var _busy = false;

  Future<void> _toggle() async {
    if (!widget.blocked) {
      final sure = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text('Заблокировать «${widget.displayName}»?'),
          content: const Text(
            'Вы не сможете звать друг друга в совместное прохождение и в '
            'соавторы маршрута. Человек не узнает о блокировке. Снять её '
            'можно здесь же или в настройках профиля.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialog).pop(false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialog).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE5484D),
              ),
              child: const Text('Заблокировать'),
            ),
          ],
        ),
      );
      if (sure != true || !mounted) return;
    }
    setState(() => _busy = true);
    final repo = ref.read(invitePrivacyRepositoryProvider);
    try {
      if (widget.blocked) {
        await repo.unblock(widget.userId);
      } else {
        await repo.block(widget.userId);
      }
      ref
        ..invalidate(publicProfileProvider(widget.userId))
        ..invalidate(blockedPeopleProvider)
        ..invalidate(invitablePeopleProvider);
      if (mounted) {
        showAppNotice(
          context,
          widget.blocked
              ? '${widget.displayName} разблокирован'
              : '${widget.displayName} заблокирован',
        );
      }
    } on Object catch (error) {
      if (mounted) {
        showAppNotice(
          context,
          companionErrorText(error),
          kind: AppNoticeKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24),
    child: Center(
      child: TextButton.icon(
        key: const ValueKey('profile-block'),
        onPressed: _busy ? null : () => unawaited(_toggle()),
        icon: Icon(
          widget.blocked ? Icons.lock_open_rounded : Icons.block_rounded,
          size: 18,
        ),
        label: Text(widget.blocked ? 'Разблокировать' : 'Заблокировать'),
        style: TextButton.styleFrom(
          foregroundColor: widget.blocked
              ? AppColors.secondaryInk
              : const Color(0xFFE5484D),
        ),
      ),
    ),
  );
}
