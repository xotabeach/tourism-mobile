import 'dart:async';
import 'dart:math' as math;

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

/// «Мой персонаж» (FRONTEND-72, FRONTEND-79): pick which of the four
/// characters you are, what it wears and the hat. Your character stands at
/// the fire, on the rope and on the group's card.
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

  Future<void> _save(
    Future<BeanHatsState> Function(BeanHatsRepository repo) change,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final next = await change(ref.read(beanHatsRepositoryProvider));
      if (!mounted) return;
      setState(() => _state = next);
      // Groups and the avatar redraw the character as it is now.
      ref.invalidate(myCompanionGroupsProvider);
      ref.invalidate(myBeanLookProvider);
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

  /// A closed hat or outfit says how to get it; an open one is put on, or
  /// taken off when it is already on.
  Future<bool> _closed(BeanHatOption option) async {
    final state = _state;
    if (state == null || option.available) return false;
    if (option.tier == BeanHatTier.points) {
      showAppNotice(
        context,
        'Откроется на ${option.pointsRequired} ТП. Сейчас у вас '
        '${state.travelPoints} ТП',
      );
    } else {
      await _showPremium(option);
    }
    return true;
  }

  Future<void> _tapHat(BeanHatOption hat) async {
    final state = _state;
    if (state == null || await _closed(hat)) return;
    await _save(
      (repo) => repo.select(state.selected == hat.slug ? null : hat.slug),
    );
  }

  Future<void> _tapOutfit(BeanHatOption? outfit) async {
    final state = _state;
    if (state == null) return;
    if (outfit != null && await _closed(outfit)) return;
    await _save((repo) => repo.selectOutfit(outfit?.slug));
  }

  Future<void> _tapKind(String slug) async {
    if (_state == null) return;
    await _save((repo) => repo.selectKind(slug));
  }

  Future<void> _showPremium(BeanHatOption option) {
    final state = _state!;
    final me = ref.read(myUserIdProvider) ?? 'me';
    final isOutfit = state.outfits.any((o) => o.slug == option.slug);
    return showModalBottomSheet<void>(
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
                height: 140,
                child: _Portrait(
                  look: _look(
                    me,
                    state,
                    hat: isOutfit ? null : option.slug,
                    outfit: isOutfit ? option.slug : null,
                  ),
                  closeUp: !isOutfit,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                option.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: AppFonts.rubik,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Входит в Тревел+ вместе со всеми шапками и одеждой. Скоро '
                'можно будет и просто купить.',
                textAlign: TextAlign.center,
                style: AppTypography.settingsRowSubtitle,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  Navigator.of(sheet).pop();
                  unawaited(
                    context.pushNamed(AppRouteNames.settingsTravelPlus),
                  );
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
  }

  /// The person's character as chosen, with [hat] or [outfit] tried on.
  BeanLook _look(
    String me,
    BeanHatsState state, {
    String? kind,
    String? hat,
    String? outfit,
    bool noOutfit = false,
  }) => BeanLook.forUser(
    me,
    kind: kind ?? state.kind,
    hat: hat ?? state.selected,
    outfit: noOutfit ? null : outfit ?? state.outfit,
  );

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 10),
    child: Text(
      text,
      style: const TextStyle(
        fontFamily: AppFonts.rubik,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.primaryInk,
      ),
    ),
  );

  Widget _grid(List<Widget> tiles, {double aspect = 0.72}) => GridView.count(
    crossAxisCount: 4,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 10,
    crossAxisSpacing: 10,
    childAspectRatio: aspect,
    children: tiles,
  );

  String? _note(BeanHatOption option) => option.available
      ? null
      : option.tier == BeanHatTier.points
      ? '${option.pointsRequired} ТП'
      : 'Тревел+';

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(myUserIdProvider) ?? 'me';
    final name =
        ref.watch(sessionProvider.select((s) => s.displayName)) ?? 'Вы';
    final state = _state;
    final current = state == null ? null : _look(me, state);
    return Scaffold(
      backgroundColor: AppColors.pageSurface,
      appBar: AppBar(
        backgroundColor: AppColors.pageSurface,
        surfaceTintColor: Colors.transparent,
        title: const Text('Мой персонаж', style: AppTypography.sectionTitle),
      ),
      body: state == null || current == null
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
                      kind: current.kind.slug,
                      outfit: state.outfit,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  state.isExpert
                      ? 'Так вас видят попутчики у костра, на связке и на '
                            'открытке. Вы эксперт: вам открыты все шапки и вся '
                            'одежда.'
                      : 'Так вас видят попутчики у костра, на связке и на '
                            'открытке.',
                  style: AppTypography.settingsRowSubtitle,
                ),
                // A server before BACKEND-71 sends hats only.
                if (state.kinds.isNotEmpty) ...[
                  _heading('Персонаж'),
                  _grid(aspect: 0.62, [
                    for (final kind in BeanKind.values)
                      _ChoiceTile(
                        title: kind.title,
                        selected: current.kind == kind,
                        onTap: () => unawaited(_tapKind(kind.slug)),
                        child: _Portrait(
                          look: _look(me, state, kind: kind.slug),
                        ),
                      ),
                  ]),
                ],
                if (state.outfits.isNotEmpty) ...[
                  _heading('Одежда'),
                  _grid(aspect: 0.62, [
                    _ChoiceTile(
                      title: 'Без одежды',
                      selected: state.outfit == null,
                      onTap: () => unawaited(_tapOutfit(null)),
                      child: _Portrait(look: _look(me, state, noOutfit: true)),
                    ),
                    for (final outfit in state.outfits)
                      _ChoiceTile(
                        title: outfit.title,
                        note: _note(outfit),
                        selected: state.outfit == outfit.slug,
                        onTap: () => unawaited(_tapOutfit(outfit)),
                        child: _Portrait(
                          look: _look(me, state, outfit: outfit.slug),
                        ),
                      ),
                  ]),
                ],
                for (final tier in BeanHatTier.values) ...[
                  _heading(switch (tier) {
                    BeanHatTier.free => 'Бесплатные',
                    BeanHatTier.points =>
                      'За очки ТП · у вас ${state.travelPoints} ТП',
                    BeanHatTier.premium => 'Тревел+ и покупка',
                  }),
                  _grid([
                    for (final hat in state.items)
                      if (hat.tier == tier)
                        _ChoiceTile(
                          title: hat.title,
                          note: _note(hat),
                          selected: state.selected == hat.slug,
                          onTap: () => unawaited(_tapHat(hat)),
                          child: _Portrait(
                            look: _look(me, state, hat: hat.slug),
                            closeUp: true,
                          ),
                        ),
                  ]),
                ],
              ],
            ),
    );
  }
}

/// One choice: a character drawn in it, its name and how to open it.
class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.title,
    required this.selected,
    required this.onTap,
    required this.child,
    this.note,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  /// What opens a closed one: «1500 ТП», «Тревел+».
  final String? note;

  @override
  Widget build(BuildContext context) {
    final locked = note != null;
    return Semantics(
      button: true,
      selected: selected,
      label: [title, if (locked) 'закрыто, $note'].join(', '),
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
                    Positioned.fill(
                      child: Opacity(opacity: locked ? 0.55 : 1, child: child),
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
                title,
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
                  note!,
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

/// A character in a tile: whole, or from the shoulders up for hats.
class _Portrait extends StatelessWidget {
  const _Portrait({required this.look, this.closeUp = false});

  final BeanLook look;
  final bool closeUp;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _PortraitPainter(look, closeUp: closeUp));
}

class _PortraitPainter extends CustomPainter {
  _PortraitPainter(this.look, {required this.closeUp});

  final BeanLook look;
  final bool closeUp;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    // The drawing's own height for this build, against the blue one.
    final ratio = beanHeight(look.kind, 1);
    if (closeUp) {
      // The head and the hat fill the tile, room above for tall hats.
      final tall = size.height * 1.3;
      paintBean(
        canvas,
        Offset(size.width / 2, size.height * 0.36 + tall * 0.92),
        tall / ratio,
        look.color,
        BeanPose(look: look, lookX: 0.4),
      );
    } else {
      // Whole, with room for a hat on top.
      final tall = math.min(size.height * 0.74, size.width * 1.25);
      paintBean(
        canvas,
        Offset(size.width / 2, size.height - 4),
        tall / ratio,
        look.color,
        BeanPose(look: look, lookX: 0.4),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PortraitPainter old) =>
      old.look.kind != look.kind ||
      old.look.accessory != look.accessory ||
      old.look.outfit != look.outfit ||
      old.closeUp != closeUp;
}
