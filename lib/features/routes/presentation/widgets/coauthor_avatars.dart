import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/features/companions/application/companions_providers.dart';
import 'package:tourism_mobile/features/companions/presentation/user_avatar.dart';
import 'package:tourism_mobile/routing/app_router.dart';

/// One author shown in [CoauthorAvatars].
class AvatarPerson {
  const AvatarPerson({
    required this.userId,
    this.avatarUrl,
    this.beanKind,
    this.beanHat,
  });

  final String? userId;
  final String? avatarUrl;

  /// The character and hat drawn without a picture (FRONTEND-97).
  final String? beanKind;
  final String? beanHat;
}

/// The authors of a co-written route as DESIGN-19 draws them: avatars
/// overlapping and every few seconds changing places; a tap spreads them
/// apart, a second tap on one opens that author's profile.
class CoauthorAvatars extends ConsumerStatefulWidget {
  const CoauthorAvatars({required this.people, this.radius = 18.5, super.key});

  final List<AvatarPerson> people;
  final double radius;

  static String names(String owner, List<String> others) {
    final all = [owner, ...others].where((name) => name.isNotEmpty).toList();
    if (all.length <= 1) return all.join();
    return '${all.sublist(0, all.length - 1).join(', ')} и ${all.last}';
  }

  @override
  ConsumerState<CoauthorAvatars> createState() => _CoauthorAvatarsState();
}

class _CoauthorAvatarsState extends ConsumerState<CoauthorAvatars> {
  var _spread = false;
  var _shift = 0;
  Timer? _swap;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _swap?.cancel();
    if (!MediaQuery.disableAnimationsOf(context) && widget.people.length > 1) {
      _swap = Timer.periodic(const Duration(seconds: 3), (_) {
        if (mounted && !_spread) setState(() => _shift++);
      });
    }
  }

  @override
  void dispose() {
    _swap?.cancel();
    super.dispose();
  }

  void _open(AvatarPerson person) {
    final id = person.userId;
    if (id == null || id.isEmpty) return;
    unawaited(
      context.pushNamed(
        AppRouteNames.userProfile,
        pathParameters: {'userId': id},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final myId = ref.watch(myUserIdProvider);
    final people = widget.people;
    final size = widget.radius * 2 + 3;
    final step = _spread ? size + 6 : size * 0.55;
    final width = size + step * (people.length - 1);
    // The one on top changes every few seconds.
    final order = [
      for (var i = 0; i < people.length; i++) (i + _shift) % people.length,
    ];
    return Semantics(
      button: true,
      label: _spread ? 'Выберите автора' : 'Авторы маршрута',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _spread ? null : () => setState(() => _spread = true),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutBack,
          width: width,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final index in order.reversed)
                AnimatedPositioned(
                  key: ValueKey('coauthor-$index'),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  left: step * index,
                  top: 0,
                  child: GestureDetector(
                    onTap: _spread ? () => _open(people[index]) : null,
                    child: Container(
                      padding: const EdgeInsets.all(1.5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                      ),
                      child: (people[index].avatarUrl ?? '').isEmpty
                          ? UserAvatar(
                              userId: people[index].userId,
                              avatarUrl: null,
                              beanKind: people[index].beanKind,
                              beanHat: people[index].beanHat,
                              size: widget.radius * 2,
                              own: people[index].userId == myId,
                            )
                          : CircleAvatar(
                              radius: widget.radius,
                              backgroundImage: AppImages.avatarProvider(
                                config: config,
                                avatarUrl: people[index].avatarUrl,
                              ),
                            ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
