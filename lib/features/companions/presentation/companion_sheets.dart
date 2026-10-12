import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_list_skeleton.dart';
import 'package:tourism_mobile/core/design/components/app_notice.dart';
import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/features/companions/application/companions_providers.dart';
import 'package:tourism_mobile/features/companions/domain/companion_group.dart';
import 'package:tourism_mobile/features/companions/presentation/flat/flat_style.dart';
import 'package:tourism_mobile/routing/app_router.dart';

/// The words for a refused group action: the server already says it in
/// Russian; only a dropped connection needs our own.
String companionErrorText(Object error) {
  if (error is NetworkFailure) return 'Нет связи. Попробуйте ещё раз';
  if (error is AppFailure && error.code != null && error.message.isNotEmpty) {
    return error.message;
  }
  return 'Не получилось. Попробуйте ещё раз';
}

/// The server's code for «you are already in another live group».
const companionBusyCode = 'companion_already_in_group';

void openCompanionGroup(BuildContext context, String groupId) => unawaited(
  context.pushNamed(
    AppRouteNames.companionGroup,
    pathParameters: {'groupId': groupId},
  ),
);

/// Shows why a group action was refused. Already being in another group
/// is not a dead end: the notice offers to go to that group (FRONTEND-73).
Future<void> showCompanionError(
  BuildContext context,
  WidgetRef ref,
  Object error,
) async {
  final busy = error is AppFailure && error.code == companionBusyCode;
  if (!busy) {
    showAppNotice(
      context,
      companionErrorText(error),
      kind: AppNoticeKind.error,
    );
    return;
  }
  ref.invalidate(myCompanionGroupsProvider);
  CompanionGroup? lobby;
  try {
    lobby = activeLobbyOf(await ref.read(myCompanionGroupsProvider.future));
  } on Object {
    lobby = null;
  }
  if (!context.mounted) return;
  showAppNotice(
    context,
    companionErrorText(error),
    kind: AppNoticeKind.error,
    duration: const Duration(seconds: 6),
    actionLabel: lobby == null ? null : 'Перейти в активное лобби',
    onAction: lobby == null
        ? null
        : () => openCompanionGroup(context, lobby!.id),
  );
}

const _sheetShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
);

TextStyle _title() => const TextStyle(
  fontFamily: AppFonts.rubik,
  fontSize: 20,
  fontWeight: FontWeight.w600,
  color: AppColors.primaryInk,
);

/// A flat round face in a person's bean colour, for lists.
class BeanFace extends StatelessWidget {
  const BeanFace({required this.userId, this.size = 40, super.key});

  final String userId;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _FacePainter(FlatPalette.beanFor(userId))),
  );
}

class _FacePainter extends CustomPainter {
  _FacePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    canvas.drawCircle(Offset(r, r), r, Paint()..color = color);
    // The same face as the characters: black eyes with a shine and a
    // white smile.
    for (final side in const [-1.0, 1.0]) {
      final eye = Offset(r + side * r * 0.3, r * 0.82);
      canvas.drawOval(
        Rect.fromCenter(center: eye, width: r * 0.3, height: r * 0.48),
        Paint()..color = FlatPalette.ink,
      );
      canvas.drawCircle(
        eye.translate(r * 0.05, -r * 0.1),
        r * 0.07,
        Paint()..color = FlatPalette.white,
      );
    }
    canvas.drawPath(
      Path()
        ..moveTo(r * 0.5, r * 1.26)
        ..quadraticBezierTo(r, r * 1.36, r * 1.5, r * 1.26)
        ..cubicTo(r * 1.5, r * 1.72, r * 0.5, r * 1.72, r * 0.5, r * 1.26)
        ..close(),
      Paint()..color = FlatPalette.white,
    );
  }

  @override
  bool shouldRepaint(covariant _FacePainter old) => old.color != color;
}

/// «Позвать друзей»: mutual followers who accept invites (spec 11b D2).
Future<void> showInviteSheet(
  BuildContext context, {
  required CompanionGroup group,
  required ValueChanged<CompanionGroup> onChanged,
}) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  backgroundColor: Colors.white,
  shape: _sheetShape,
  builder: (context) => _InviteSheet(group: group, onChanged: onChanged),
);

class _InviteSheet extends ConsumerStatefulWidget {
  const _InviteSheet({required this.group, required this.onChanged});

  final CompanionGroup group;
  final ValueChanged<CompanionGroup> onChanged;

  @override
  ConsumerState<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<_InviteSheet> {
  late var _group = widget.group;
  final _busy = <String>{};
  String? _error;

  Future<void> _invite(InvitablePerson person) async {
    setState(() {
      _busy.add(person.userId);
      _error = null;
    });
    try {
      final group = await ref
          .read(companionsRepositoryProvider)
          .invite(_group.id, person.userId);
      if (!mounted) return;
      setState(() => _group = group);
      widget.onChanged(group);
    } on Object catch (error) {
      if (mounted) setState(() => _error = companionErrorText(error));
    } finally {
      if (mounted) setState(() => _busy.remove(person.userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final people = ref.watch(invitablePeopleProvider);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Позвать друзей', style: _title()),
            const SizedBox(height: 4),
            const Text(
              'Звать можно тех, на кого вы подписаны взаимно. Приглашение '
              'действует 48 часов.',
              style: AppTypography.settingsRowSubtitle,
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Color(0xFFE5484D))),
            ],
            const SizedBox(height: 12),
            Flexible(
              child: people.when(
                loading: () => const AppListSkeleton(
                  rows: 3,
                  rowHeight: 52,
                  roundLeading: true,
                  padding: EdgeInsets.zero,
                ),
                error: (error, _) => Text(companionErrorText(error)),
                data: (list) => list.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'Пока некого позвать: подпишитесь друг на друга с '
                          'друзьями или покажите им код группы.',
                          style: AppTypography.settingsRowSubtitle,
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final person = list[index];
                          final member = _group.memberOf(person.userId);
                          final already =
                              member != null &&
                              (member.state == CompanionMemberState.joined ||
                                  member.state == CompanionMemberState.invited);
                          return Row(
                            children: [
                              BeanFace(userId: person.userId),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  person.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.settingsRowTitle,
                                ),
                              ),
                              if (already)
                                Text(
                                  member.state == CompanionMemberState.joined
                                      ? 'В группе'
                                      : 'Позван',
                                  style: AppTypography.settingsRowSubtitle,
                                )
                              else
                                FilledButton(
                                  onPressed: _busy.contains(person.userId)
                                      ? null
                                      : () => _invite(person),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.primaryInk,
                                    shape: const StadiumBorder(),
                                  ),
                                  child: const Text('Позвать'),
                                ),
                            ],
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// «У меня есть код»: the organizer confirms who comes in (spec 11b D15).
Future<CompanionGroup?> showJoinCodeSheet(BuildContext context) =>
    showModalBottomSheet<CompanionGroup>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: _sheetShape,
      builder: (context) => const _JoinCodeSheet(),
    );

class _JoinCodeSheet extends ConsumerStatefulWidget {
  const _JoinCodeSheet();

  @override
  ConsumerState<_JoinCodeSheet> createState() => _JoinCodeSheetState();
}

class _JoinCodeSheetState extends ConsumerState<_JoinCodeSheet> {
  final _controller = TextEditingController();
  var _busy = false;
  String? _error;

  /// Set when the code is refused because the person is already in a live
  /// group: the sheet then offers to go there (FRONTEND-73).
  String? _lobbyId;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _controller.text.trim();
    if (code.length < 4) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final group = await ref
          .read(companionsRepositoryProvider)
          .joinByCode(code);
      if (mounted) Navigator.of(context).pop(group);
    } on Object catch (error) {
      String? lobbyId;
      if (error is AppFailure && error.code == companionBusyCode) {
        ref.invalidate(myCompanionGroupsProvider);
        try {
          lobbyId = activeLobbyOf(
            await ref.read(myCompanionGroupsProvider.future),
          )?.id;
        } on Object {
          lobbyId = null;
        }
      }
      if (mounted) {
        setState(() {
          _busy = false;
          _error = companionErrorText(error);
          _lobbyId = lobbyId;
        });
      }
    }
  }

  void _goToLobby(String id) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    unawaited(
      router.pushNamed(
        AppRouteNames.companionGroup,
        pathParameters: {'groupId': id},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, insets + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Код группы', style: _title()),
          const SizedBox(height: 4),
          const Text(
            'Попросите код у организатора. Он увидит вашу просьбу и впустит '
            'вас в группу.',
            style: AppTypography.settingsRowSubtitle,
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('companion-code-field'),
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            maxLength: 8,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppFonts.rubik,
              fontSize: 28,
              fontWeight: FontWeight.w600,
              letterSpacing: 6,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: 'ABC123',
              errorText: _error,
              filled: true,
              fillColor: const Color(0xFFF1F2F4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (_) => _join(),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _join,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryInk,
              minimumSize: const Size.fromHeight(52),
              shape: const StadiumBorder(),
            ),
            child: const Text('Попроситься в группу'),
          ),
          if (_lobbyId case final id?) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _goToLobby(id),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: const StadiumBorder(),
              ),
              child: const Text('Перейти в активное лобби'),
            ),
          ],
        ],
      ),
    );
  }
}

/// A complaint about an invitation; it also declines it.
Future<String?> showInviteReportSheet(BuildContext context) =>
    showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.white,
      shape: _sheetShape,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Пожаловаться на приглашение', style: _title()),
              const SizedBox(height: 8),
              for (final (code, label) in const [
                ('spam', 'Спам, зовут слишком часто'),
                ('abuse', 'Оскорбления или давление'),
                ('inappropriate', 'Неуместное приглашение'),
                ('other', 'Другое'),
              ])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(label),
                  onTap: () => Navigator.of(context).pop(code),
                ),
            ],
          ),
        ),
      ),
    );
