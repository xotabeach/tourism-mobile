import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/design/components/app_controls.dart';
import 'package:tourism_mobile/core/design/components/app_list_skeleton.dart';
import 'package:tourism_mobile/features/profile/application/profile_providers.dart';
import 'package:tourism_mobile/features/profile/data/public_profile_repository.dart';
import 'package:tourism_mobile/features/profile/presentation/profile_screen.dart';
import 'package:tourism_mobile/features/search/presentation/universal_search_panel.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_widgets.dart';

enum FollowListKind { followers, following }

/// «Подписчики Никиты (29)» — a Cyrillic first name in the genitive case,
/// for the regular endings only. Anything else (Latin names, nicknames with
/// digits) keeps the plain title: a wrong declension reads worse than none.
String followersTitle(String? displayName) {
  final first = (displayName ?? '').trim().split(RegExp(r'\s+')).first;
  if (!RegExp(r'^[А-ЯЁ][а-яё]{2,}$').hasMatch(first)) {
    return 'Подписчики';
  }
  final last = first[first.length - 1];
  final stem = first.substring(0, first.length - 1);
  final beforeLast = stem[stem.length - 1];
  final genitive = switch (last) {
    'а' => '$stem${'гкхжчшщ'.contains(beforeLast) ? 'и' : 'ы'}',
    'я' => '$stemи',
    'й' || 'ь' => '$stemя',
    _ when 'бвгджзклмнпрстфхцчшщ'.contains(last) => '$firstа',
    _ => null,
  };
  return genitive == null ? 'Подписчики' : 'Подписчики $genitive';
}

/// Followers of any profile, or one's own subscriptions, opened from the
/// counters on the profile (design, task FRONTEND-11).
class FollowListScreen extends ConsumerStatefulWidget {
  const FollowListScreen({
    required this.kind,
    this.userId,
    this.displayName,
    super.key,
  });

  final FollowListKind kind;

  /// Whose followers. For one's own profile this is one's own id and
  /// [displayName] is null (the title then reads «Мои подписчики»).
  final String? userId;
  final String? displayName;

  @override
  ConsumerState<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends ConsumerState<FollowListScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  var _query = '';
  Future<List<PublicUserProfile>>? _load;
  List<PublicUserProfile>? _all;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _reload() {
    final repo = ref.read(publicProfileRepositoryProvider);
    final mock = ref.read(appConfigProvider).useMockData;
    final userId = widget.userId;
    setState(() {
      _load = switch (widget.kind) {
        // Followers are searched on the server: the list can be long.
        FollowListKind.followers when !mock && userId != null => repo.followers(
          userId,
          query: _query,
        ),
        // One's own subscriptions (and every mock list) come whole and are
        // narrowed here.
        _ => ref.read(profileSubscriptionsProvider.future),
      };
    });
  }

  bool get _filtersLocally =>
      widget.kind == FollowListKind.following ||
      ref.read(appConfigProvider).useMockData ||
      widget.userId == null;

  void _onQuery(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _query = value.trim();
      if (_filtersLocally) {
        setState(() {});
      } else {
        _reload();
      }
    });
  }

  String get _title => switch (widget.kind) {
    FollowListKind.following => 'Мои подписки',
    FollowListKind.followers =>
      widget.displayName == null
          ? 'Мои подписчики'
          : followersTitle(widget.displayName),
  };

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PublicUserProfile>>(
      future: _load,
      builder: (context, snapshot) {
        final loaded = snapshot.data;
        if (loaded != null && _query.isEmpty) {
          _all = loaded;
        }
        final needle = _query.toLowerCase();
        final items = loaded == null
            ? null
            : _filtersLocally && needle.isNotEmpty
            ? [
                for (final p in loaded)
                  if (p.displayName.toLowerCase().contains(needle)) p,
              ]
            : loaded;
        final count = _all?.length;
        return SettingsScaffold(
          barTitle: count == null ? _title : '$_title ($count)',
          spaceChildren: false,
          children: [
            AppSearchFilterRow(
              showFilterButton: false,
              hintText: 'Поиск по имени',
              controller: _search,
              onSearchChanged: _onQuery,
              onSearchClear: () => _onQuery(''),
            ),
            const SizedBox(height: 12),
            if (snapshot.hasError)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Не удалось загрузить',
                    style: AppTypography.settingsRowSubtitle,
                  ),
                  TextButton(
                    onPressed: _reload,
                    child: const Text('Повторить'),
                  ),
                ],
              )
            else if (items == null)
              const AppListSkeleton(rows: 5)
            else if (items.isEmpty)
              Text(
                _query.isNotEmpty
                    ? 'Никого не нашли'
                    : widget.kind == FollowListKind.following
                    ? 'Вы пока ни на кого не подписаны'
                    : 'Подписчиков пока нет',
                style: AppTypography.settingsRowSubtitle,
              )
            else
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                DiscoveryProfileCard(
                  key: ValueKey('follow-list-${items[i].id}'),
                  profile: items[i],
                  onTap: () => Navigator.of(context).push<void>(
                    CupertinoPageRoute<void>(
                      builder: (_) => ProfileScreen(userId: items[i].id),
                    ),
                  ),
                ),
              ],
          ],
        );
      },
    );
  }
}
