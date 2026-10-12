import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_notice.dart';
import 'package:tourism_mobile/core/design/components/app_skeleton.dart';
import 'package:tourism_mobile/features/companions/application/companions_providers.dart';
import 'package:tourism_mobile/features/companions/data/bean_hats_repository.dart';
import 'package:tourism_mobile/features/companions/presentation/companion_sheets.dart';
import 'package:tourism_mobile/features/companions/presentation/flat/campfire_scene.dart';
import 'package:tourism_mobile/features/companions/presentation/flat/flat_style.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/routing/app_router.dart';

/// «Мой персонаж» (FRONTEND-72): pick the hat your character wears at the
/// fire, on the rope and on the group's card. Only the hat is chosen; the
/// shape, markings and colour come with the account.
class CharacterScreen extends ConsumerStatefulWidget {
  const CharacterScreen({super.key});

  static const routePath = 'character';

  @override
  ConsumerState<CharacterScreen> createState() => _CharacterScreenState();
}

class _CharacterScreenState extends ConsumerState<CharacterScreen> {
  BeanHatsState? _state;
  Object? _error;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final state = await ref.read(beanHatsRepositoryProvider).load();
      if (mounted) setState(() => _state = state);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _tap(BeanHatOption hat) async {
    final state = _state;
    if (state == null || _busy) return;
    if (!hat.available) {
      if (hat.tier == BeanHatTier.points) {
        showAppNotice(
          context,
          'Откроется на ${hat.pointsRequired} ТП. Сейчас у вас '
          '${state.travelPoints} ТП',
        );
      } else {
        await _showPremium(hat);
      }
      return;
    }
    setState(() => _busy = true);
    try {
      final next = await ref
          .read(beanHatsRepositoryProvider)
          .select(state.selected == hat.slug ? null : hat.slug);
      if (!mounted) return;
      setState(() => _state = next);
      // Groups redraw the character with its new hat.
      ref.invalidate(myCompanionGroupsProvider);
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

  Future<void> _showPremium(BeanHatOption hat) => showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 120,
              child: _HatPortrait(
                userId: ref.read(myUserIdProvider) ?? 'me',
                hat: hat.slug,
                size: 110,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hat.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppFonts.rubik,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Входит в Тревел+ вместе со всеми шапками. Скоро её можно будет '
              'и просто купить.',
              textAlign: TextAlign.center,
              style: AppTypography.settingsRowSubtitle,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                Navigator.of(sheet).pop();
                unawaited(context.pushNamed(AppRouteNames.settingsTravelPlus));
              },
              style: FilledButton.styleFrom(
                backgroundColor: FlatPalette.flameOuter,
                minimumSize: const Size.fromHeight(52),
                shape: const StadiumBorder(),
              ),
              child: const Text('Тревел+'),
            ),
            const SizedBox(height: 8),
            const OutlinedButton(
              onPressed: null,
              style: ButtonStyle(
                minimumSize: WidgetStatePropertyAll(Size.fromHeight(50)),
                shape: WidgetStatePropertyAll(StadiumBorder()),
              ),
              child: Text('Купить · скоро'),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(myUserIdProvider) ?? 'me';
    final name =
        ref.watch(sessionProvider.select((s) => s.displayName)) ?? 'Вы';
    final state = _state;
    return Scaffold(
      backgroundColor: AppColors.pageSurface,
      appBar: AppBar(
        backgroundColor: AppColors.pageSurface,
        surfaceTintColor: Colors.transparent,
        title: const Text('Мой персонаж', style: AppTypography.sectionTitle),
      ),
      body: state == null
          ? (_error == null
                ? const AppShimmer(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        children: [
                          AppSkeleton(
                            width: double.infinity,
                            height: 220,
                            borderRadius: 24,
                          ),
                          SizedBox(height: 20),
                          AppSkeleton(
                            width: double.infinity,
                            height: 260,
                            borderRadius: 20,
                          ),
                        ],
                      ),
                    ),
                  )
                : Center(
                    child: TextButton(
                      onPressed: () {
                        setState(() => _error = null);
                        unawaited(_load());
                      },
                      child: Text('${companionErrorText(_error!)}. Повторить'),
                    ),
                  ))
          : ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                MediaQuery.paddingOf(context).bottom + 24,
              ),
              children: [
                CampfireScene(
                  height: 230,
                  closeUp: true,
                  members: [
                    CampMember(
                      userId: me,
                      name: name,
                      ready: true,
                      hat: state.selected,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Так вас видят попутчики у костра, на связке и на открытке. '
                  'Форма и цвет персонажа свои у каждого, шапку выбираете вы.',
                  style: AppTypography.settingsRowSubtitle,
                ),
                for (final tier in BeanHatTier.values) ...[
                  const SizedBox(height: 20),
                  Text(
                    switch (tier) {
                      BeanHatTier.free => 'Бесплатные',
                      BeanHatTier.points =>
                        'За очки ТП · у вас ${state.travelPoints} ТП',
                      BeanHatTier.premium => 'Тревел+ и покупка',
                    },
                    style: const TextStyle(
                      fontFamily: AppFonts.rubik,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryInk,
                    ),
                  ),
                  const SizedBox(height: 10),
                  GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.72,
                    children: [
                      for (final hat in state.items)
                        if (hat.tier == tier)
                          _HatTile(
                            userId: me,
                            hat: hat,
                            selected: state.selected == hat.slug,
                            onTap: () => unawaited(_tap(hat)),
                          ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}

class _HatTile extends StatelessWidget {
  const _HatTile({
    required this.userId,
    required this.hat,
    required this.selected,
    required this.onTap,
  });

  final String userId;
  final BeanHatOption hat;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final locked = !hat.available;
    final note = !locked
        ? null
        : hat.tier == BeanHatTier.points
        ? '${hat.pointsRequired} ТП'
        : 'Тревел+';
    return Semantics(
      button: true,
      selected: selected,
      label: [hat.title, if (note != null) 'закрыта, $note'].join(', '),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFFF1E0) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? FlatPalette.flameOuter
                  : const Color(0xFFE8E8EA),
              width: selected ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Opacity(
                      opacity: locked ? 0.55 : 1,
                      child: _HatPortrait(
                        userId: userId,
                        hat: hat.slug,
                        size: 64,
                      ),
                    ),
                    if (locked)
                      Positioned(
                        right: 2,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: FlatPalette.ink,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.lock_rounded,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                hat.title,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppFonts.rubik,
                  fontSize: 10,
                  height: 1.15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primaryInk,
                ),
              ),
              if (note != null)
                Text(
                  note,
                  style: const TextStyle(
                    fontFamily: AppFonts.rubik,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: FlatPalette.flameOuter,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The person's own character, from the waist up, wearing [hat].
class _HatPortrait extends StatelessWidget {
  const _HatPortrait({
    required this.userId,
    required this.hat,
    required this.size,
  });

  final String userId;
  final String hat;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _PortraitPainter(userId, hat)),
  );
}

class _PortraitPainter extends CustomPainter {
  _PortraitPainter(this.userId, this.hat);

  final String userId;
  final String hat;

  @override
  void paint(Canvas canvas, Size size) {
    // A close-up from the shoulders: the hat and the face fill the tile,
    // with room above for the tall ones.
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    paintBean(
      canvas,
      Offset(size.width / 2, size.height * 1.32),
      size.height * 0.88,
      FlatPalette.beanFor(userId),
      BeanPose(look: BeanLook.forUser(userId, hat: hat), lookX: 0.4),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PortraitPainter old) =>
      old.userId != userId || old.hat != hat;
}
