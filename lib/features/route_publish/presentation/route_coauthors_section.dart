import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_notice.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/features/companions/application/companions_providers.dart';
import 'package:tourism_mobile/features/companions/domain/companion_group.dart';
import 'package:tourism_mobile/features/companions/presentation/user_avatar.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/route_publish/application/route_draft_providers.dart';
import 'package:tourism_mobile/features/route_publish/data/route_coauthors_repository.dart';
import 'package:tourism_mobile/features/route_publish/presentation/publish_route_design_tokens.dart';
import 'package:tourism_mobile/features/routes/domain/route.dart';

const maxRouteCoauthors = 3;

/// «Соавторство» on the publish page, as DESIGN-19 draws it (spec 11c D7).
///
/// The owner picks up to three people; the route goes to the moderator once
/// every author pressed «Опубликовать». A co-author sees whose route it is
/// and may decline.
class RouteCoauthorsSection extends ConsumerStatefulWidget {
  const RouteCoauthorsSection({
    required this.u,
    required this.routeId,
    required this.selected,
    required this.onChanged,
    this.onLeft,
    super.key,
  });

  final double Function(double) u;

  /// Null for a route not saved on the server yet.
  final String? routeId;

  /// The owner's current choice; null until they change it.
  final Set<String>? selected;
  final ValueChanged<Set<String>> onChanged;

  /// A co-author declined; the page leaves the route.
  final VoidCallback? onLeft;

  @override
  ConsumerState<RouteCoauthorsSection> createState() =>
      _RouteCoauthorsSectionState();
}

class _RouteCoauthorsSectionState extends ConsumerState<RouteCoauthorsSection> {
  var _expanded = false;
  var _query = '';
  final _pages = PageController();
  var _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  double u(double value) => widget.u(value);

  @override
  Widget build(BuildContext context) {
    final routeId = widget.routeId;
    final info = routeId == null
        ? null
        : ref.watch(routeCoauthorsInfoProvider(routeId)).valueOrNull;
    if (info != null && !info.isOwner) return _coauthorView(info);
    final chosen =
        widget.selected ??
        {
          for (final coauthor in info?.coauthors ?? const <RouteCoauthor>[])
            coauthor.userId,
        };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('Соавторство:', style: _title())),
            Semantics(
              button: true,
              label: 'Добавить соавторов',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _expanded = !_expanded),
                child: SizedBox(
                  height: u(44),
                  child: Center(
                    child: Text(
                      'Добавить',
                      style: TextStyle(
                        fontFamily: AppFonts.rubik,
                        fontSize: u(16),
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF4C4C4C),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: u(8)),
        Container(
          decoration: BoxDecoration(
            color: PublishRouteDesignTokens.surface,
            borderRadius: BorderRadius.circular(u(18)),
            border: Border.all(color: const Color(0xFFE2E2E2)),
          ),
          padding: EdgeInsets.all(u(14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ownerRow(chosen, info),
              if (_expanded) ...[
                Padding(
                  padding: EdgeInsets.symmetric(vertical: u(12)),
                  child: const Divider(height: 1, color: Color(0xFFE6E6E6)),
                ),
                _searchField(),
                SizedBox(height: u(12)),
                _people(chosen),
              ],
              if (chosen.isNotEmpty) ...[
                SizedBox(height: u(14)),
                _ConsentNote(u: u),
              ],
            ],
          ),
        ),
      ],
    );
  }

  TextStyle _title() => TextStyle(
    fontFamily: AppFonts.rubik,
    fontSize: u(20),
    fontWeight: FontWeight.w600,
    color: PublishRouteDesignTokens.dark,
  );

  Widget _ownerRow(Set<String> chosen, RouteCoauthorsInfo? info) {
    final session = ref.watch(sessionProvider);
    final names = {
      for (final coauthor in info?.coauthors ?? const <RouteCoauthor>[])
        coauthor.userId: coauthor,
    };
    final people = ref.watch(invitablePeopleProvider).valueOrNull ?? const [];
    final byId = {for (final person in people) person.userId: person};
    final chosenNames = [
      for (final id in chosen)
        names[id]?.displayName ?? byId[id]?.displayName ?? '',
    ].where((name) => name.isNotEmpty).toList();
    return Semantics(
      button: true,
      label: _expanded ? 'Свернуть' : 'Выбрать соавторов',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _expanded = !_expanded),
        child: Row(
          children: [
            UserAvatar(
              userId: session.userId,
              avatarUrl: session.avatarUrl,
              size: u(44),
              own: true,
            ),
            SizedBox(width: u(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    [session.displayName ?? 'Вы', ...chosenNames].join(' и '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppFonts.rubik,
                      fontSize: u(17),
                      fontWeight: FontWeight.w600,
                      color: PublishRouteDesignTokens.dark,
                    ),
                  ),
                  Text(
                    chosen.isEmpty
                        ? 'Можно позвать до $maxRouteCoauthors соавторов'
                        : 'Маршрут в соавторстве · ${_consentLine(chosen, info)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppFonts.rubik,
                      fontSize: u(13),
                      color: PublishRouteDesignTokens.mediumText,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              _expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: u(30),
              color: PublishRouteDesignTokens.dark,
            ),
          ],
        ),
      ),
    );
  }

  static String _consentLine(Set<String> chosen, RouteCoauthorsInfo? info) {
    final agreed = (info?.coauthors ?? const <RouteCoauthor>[])
        .where((c) => chosen.contains(c.userId) && c.consented)
        .length;
    return 'согласились $agreed из ${chosen.length}';
  }

  Widget _searchField() => SizedBox(
    height: u(48),
    child: TextField(
      key: const ValueKey('coauthor-search'),
      onChanged: (value) => setState(() {
        _query = value.trim().toLowerCase();
        _page = 0;
        if (_pages.hasClients) _pages.jumpToPage(0);
      }),
      style: TextStyle(fontFamily: AppFonts.rubik, fontSize: u(16)),
      decoration: InputDecoration(
        hintText: 'Искать людей',
        prefixIcon: Icon(Icons.search_rounded, size: u(24)),
        filled: true,
        fillColor: PublishRouteDesignTokens.fieldBackground,
        contentPadding: EdgeInsets.zero,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(u(24)),
          borderSide: BorderSide.none,
        ),
      ),
    ),
  );

  Widget _people(Set<String> chosen) {
    final async = ref.watch(invitablePeopleProvider);
    return async.when(
      loading: () => SizedBox(height: u(240)),
      error: (_, _) => const Text(
        'Не удалось загрузить людей',
        style: AppTypography.settingsRowSubtitle,
      ),
      data: (people) {
        final shown = [
          for (final person in people)
            if (_query.isEmpty ||
                person.displayName.toLowerCase().contains(_query))
              person,
        ];
        if (shown.isEmpty) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: u(16)),
            child: Text(
              people.isEmpty
                  ? 'Позвать можно тех, на кого вы подписаны взаимно. Пока '
                        'таких нет.'
                  : 'Никого не нашли',
              style: AppTypography.settingsRowSubtitle,
            ),
          );
        }
        const perPage = 3;
        final pages = (shown.length / perPage).ceil();
        return Column(
          children: [
            SizedBox(
              height: (u(76) + u(8)) * perPage.clamp(1, shown.length),
              child: PageView.builder(
                controller: _pages,
                itemCount: pages,
                onPageChanged: (page) => setState(() => _page = page),
                itemBuilder: (context, page) => Column(
                  children: [
                    for (
                      var i = page * perPage;
                      i < shown.length && i < (page + 1) * perPage;
                      i++
                    )
                      Padding(
                        padding: EdgeInsets.only(bottom: u(8)),
                        child: _PersonCard(
                          u: u,
                          person: shown[i],
                          selected: chosen.contains(shown[i].userId),
                          onTap: () => _toggle(chosen, shown[i].userId),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (pages > 1)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < pages; i++)
                    Container(
                      margin: EdgeInsets.symmetric(horizontal: u(3)),
                      width: u(i == _page ? 9 : 7),
                      height: u(i == _page ? 9 : 7),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _page
                            ? PublishRouteDesignTokens.dark
                            : const Color(0xFFCFCFCF),
                      ),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }

  void _toggle(Set<String> chosen, String userId) {
    final next = {...chosen};
    if (!next.remove(userId)) {
      if (next.length >= maxRouteCoauthors) {
        showAppNotice(
          context,
          'Соавторов может быть не больше $maxRouteCoauthors',
          kind: AppNoticeKind.error,
        );
        return;
      }
      next.add(userId);
    }
    widget.onChanged(next);
  }

  Widget _coauthorView(RouteCoauthorsInfo info) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Соавторство:', style: _title()),
        SizedBox(height: u(8)),
        Container(
          padding: EdgeInsets.all(u(14)),
          decoration: BoxDecoration(
            color: PublishRouteDesignTokens.selectedLightBlue,
            borderRadius: BorderRadius.circular(u(18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Вас позвали в соавторы',
                style: TextStyle(
                  fontFamily: AppFonts.rubik,
                  fontSize: u(17),
                  fontWeight: FontWeight.w600,
                  color: PublishRouteDesignTokens.dark,
                ),
              ),
              SizedBox(height: u(4)),
              Text(
                'Можно поправить маршрут. Нажмите «Опубликовать», чтобы '
                'согласиться: на проверку маршрут уйдёт, когда согласятся все '
                'авторы. После любой правки согласиться нужно заново.',
                style: TextStyle(
                  fontFamily: AppFonts.rubik,
                  fontSize: u(14),
                  height: 1.35,
                  color: PublishRouteDesignTokens.mediumText,
                ),
              ),
              SizedBox(height: u(10)),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () async {
                    final routeId = widget.routeId;
                    if (routeId == null) return;
                    await ref
                        .read(routeCoauthorsRepositoryProvider)
                        .leave(routeId);
                    widget.onLeft?.call();
                  },
                  child: const Text(
                    'Отказаться от соавторства',
                    style: TextStyle(color: PublishRouteDesignTokens.error),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PersonCard extends ConsumerWidget {
  const _PersonCard({
    required this.u,
    required this.person,
    required this.selected,
    required this.onTap,
  });

  final double Function(double) u;
  final InvitablePerson person;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final radius = BorderRadius.circular(u(18));
    return Semantics(
      button: true,
      selected: selected,
      label: '${person.displayName}, ${selected ? 'соавтор' : 'выбрать'}',
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: radius,
          child: SizedBox(
            height: u(76),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // The person's cover, darkened so the white text reads.
                if (person.coverUrl != null)
                  Image(
                    image: AppImages.imageProvider(
                      resolvedUrl: AppImages.resolveMediaUrl(
                        config,
                        person.coverUrl,
                      ),
                    ),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const ColoredBox(color: Color(0xFF5A3A2A)),
                  )
                else
                  const ColoredBox(color: Color(0xFF5A3A2A)),
                const ColoredBox(color: Color(0x66000000)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: u(14)),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(u(2)),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: UserAvatar(
                          userId: person.userId,
                          avatarUrl: person.avatarUrl,
                          beanKind: person.beanKind,
                          beanHat: person.beanHat,
                          size: u(44),
                        ),
                      ),
                      SizedBox(width: u(12)),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              person.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: AppFonts.rubik,
                                fontSize: u(17),
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            if (person.rankTitle != null)
                              Text(
                                person.rankTitle!,
                                style: TextStyle(
                                  fontFamily: AppFonts.rubik,
                                  fontSize: u(13),
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                          ],
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: u(40),
                        height: u(40),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.28),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: u(22),
                          color: selected
                              ? PublishRouteDesignTokens.dark
                              : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConsentNote extends StatelessWidget {
  const _ConsentNote({required this.u});

  final double Function(double) u;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(u(14)),
    decoration: BoxDecoration(
      color: PublishRouteDesignTokens.selectedLightBlue,
      borderRadius: BorderRadius.circular(u(16)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.check_circle_outline_rounded,
          size: u(34),
          color: PublishRouteDesignTokens.primaryBlue,
        ),
        SizedBox(width: u(12)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Обоюдное согласие',
                style: TextStyle(
                  fontFamily: AppFonts.rubik,
                  fontSize: u(16),
                  fontWeight: FontWeight.w600,
                  color: PublishRouteDesignTokens.dark,
                ),
              ),
              SizedBox(height: u(2)),
              Text(
                'Маршрут будет отправлен на модерацию только после публикации '
                'с аккаунтов всех соавторов',
                style: TextStyle(
                  fontFamily: AppFonts.rubik,
                  fontSize: u(13),
                  height: 1.3,
                  color: PublishRouteDesignTokens.mediumText,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
