import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/features/companions/application/companions_providers.dart';
import 'package:tourism_mobile/features/companions/domain/companion_group.dart';
import 'package:tourism_mobile/features/companions/presentation/companion_group_screen.dart';
import 'package:tourism_mobile/features/companions/presentation/flat/rope_view.dart';
import 'package:tourism_mobile/routing/app_router.dart';

/// The group on the run screen: the «связка», refreshed about every half a
/// minute while the screen is open (spec 11b D6). Nothing for a solo run.
class RunGroupStrip extends ConsumerStatefulWidget {
  const RunGroupStrip({required this.routeId, super.key});

  final String routeId;

  @override
  ConsumerState<RunGroupStrip> createState() => _RunGroupStripState();
}

class _RunGroupStripState extends ConsumerState<RunGroupStrip> {
  CompanionGroup? _group;
  CompanionProgress? _progress;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final repository = ref.read(companionsRepositoryProvider);
    try {
      final group =
          _group ??
          (await repository.myGroups())
              .where(
                (g) =>
                    g.routeId == widget.routeId &&
                    g.status == CompanionGroupStatus.started &&
                    g.isInside,
              )
              .firstOrNull;
      if (group == null) return;
      final progress = await repository.progress(group.id);
      if (!mounted) return;
      setState(() {
        _group = group;
        _progress = progress;
      });
    } on Object {
      // The run goes on without the group strip; it tries again later.
    }
    if (!mounted || _group == null) return;
    _poll?.cancel();
    _poll = Timer(CompanionGroupScreen.walkingPoll, () => unawaited(_load()));
  }

  @override
  Widget build(BuildContext context) {
    final group = _group;
    final progress = _progress;
    if (group == null || progress == null) return const SizedBox.shrink();
    final walking = progress.members
        .where((m) => m.status == CompanionRunStatus.walking)
        .length;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Semantics(
        button: true,
        label: 'Открыть группу',
        child: GestureDetector(
          onTap: () => unawaited(
            context.pushNamed(
              AppRouteNames.companionGroup,
              pathParameters: {'groupId': group.id},
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Связка · в пути $walking из ${progress.members.length}',
                style: AppTypography.settingsRowTitle,
              ),
              const SizedBox(height: 6),
              RopeView(progress: progress, height: 130),
            ],
          ),
        ),
      ),
    );
  }
}
