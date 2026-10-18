import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/features/companions/application/companions_providers.dart';
import 'package:tourism_mobile/features/companions/presentation/flat/bean_portrait.dart';
import 'package:tourism_mobile/features/companions/presentation/flat/flat_style.dart';

/// Someone's avatar (FRONTEND-97): their own picture when they have one,
/// otherwise their companion character's portrait, head and hat. For the
/// signed-in person ([own]) the character comes from their own settings
/// and changes as soon as they pick another one or another hat.
class UserAvatar extends ConsumerWidget {
  const UserAvatar({
    required this.userId,
    required this.avatarUrl,
    required this.size,
    this.beanKind,
    this.beanHat,
    this.own = false,
    super.key,
  });

  final String? userId;
  final String? avatarUrl;
  final double size;
  final String? beanKind;
  final String? beanHat;
  final bool own;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = avatarUrl;
    if (url != null && url.isNotEmpty) {
      return ClipOval(
        child: Image(
          image: AppImages.avatarProvider(
            config: ref.watch(appConfigProvider),
            avatarUrl: url,
          ),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, _, _) => _portrait(ref),
        ),
      );
    }
    return _portrait(ref);
  }

  Widget _portrait(WidgetRef ref) {
    final mine = own ? ref.watch(myBeanLookProvider).valueOrNull : null;
    return BeanPortrait(
      look: BeanLook.forUser(
        userId ?? '',
        kind: mine?.kind ?? beanKind,
        hat: mine?.hat ?? beanHat,
      ),
      size: size,
    );
  }
}
