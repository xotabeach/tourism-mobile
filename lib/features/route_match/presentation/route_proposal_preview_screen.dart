import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/design/components/app_list_skeleton.dart';
import 'package:tourism_mobile/core/design/components/app_notice.dart';
import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/route_match/application/route_match_providers.dart';
import 'package:tourism_mobile/features/route_match/domain/route_proposal_preview.dart';
import 'package:tourism_mobile/features/routes/presentation/widgets/route_static_map.dart';

class RouteProposalPreviewScreen extends ConsumerStatefulWidget {
  const RouteProposalPreviewScreen({required this.proposalId, super.key});
  final String proposalId;
  @override
  ConsumerState<RouteProposalPreviewScreen> createState() =>
      _RouteProposalPreviewScreenState();
}

class _RouteProposalPreviewScreenState
    extends ConsumerState<RouteProposalPreviewScreen> {
  bool _savingDate = false;

  Future<void> _pickDate(DateTime? current) async {
    final date = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    setState(() => _savingDate = true);
    try {
      await ref
          .read(routeMatchRepositoryProvider)
          .updateProposalDate(widget.proposalId, date);
      ref.invalidate(proposalPreviewProvider(widget.proposalId));
    } on AppFailure catch (error) {
      if (mounted) showAppNotice(context, error.message);
    } finally {
      if (mounted) setState(() => _savingDate = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = ref.watch(proposalPreviewProvider(widget.proposalId));
    final config = ref.watch(appConfigProvider);
    final token = ref.watch(sessionProvider.select((s) => s.accessToken));
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('План маршрута'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Карта'),
              Tab(text: 'По дням'),
            ],
          ),
        ),
        body: preview.when(
          loading: () => const AppListSkeleton(rows: 5),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    error is AppFailure
                        ? error.message
                        : 'Не удалось загрузить маршрут',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => ref.invalidate(
                      proposalPreviewProvider(widget.proposalId),
                    ),
                    child: const Text('Попробовать ещё раз'),
                  ),
                ],
              ),
            ),
          ),
          data: (data) => TabBarView(
            children: [
              Column(
                children: [
                  if (data.synthetic)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Показана предварительная схема. Дорожный путь пока не подтверждён.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: LayoutBuilder(
                        builder: (context, constraints) => InteractiveViewer(
                          minScale: 1,
                          maxScale: 6,
                          child: RouteStaticMap(
                            staticMapUrl: data.staticMapUrl,
                            stops: data.stops,
                            geometry: data.geometry,
                            config: config,
                            height: constraints.maxHeight,
                            interactive: false,
                            imageHeaders: token == null
                                ? const {}
                                : {'Authorization': 'Bearer $token'},
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  OutlinedButton.icon(
                    onPressed: _savingDate
                        ? null
                        : () => _pickDate(data.startDate),
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text(
                      data.startDate == null
                          ? 'Выбрать дату начала'
                          : 'Начало: ${_dateLabel(data.startDate!)}',
                    ),
                  ),
                  for (final warning in data.warnings)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(warning),
                    ),
                  if (data.days.isEmpty)
                    const Text(
                      'План по дням для этого маршрута пока недоступен.',
                    ),
                  for (final day in data.days)
                    _DayPlan(day: day, startDate: data.startDate),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _dateLabel(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

class _DayPlan extends StatelessWidget {
  const _DayPlan({required this.day, this.startDate});
  final TripDay day;
  final DateTime? startDate;
  @override
  Widget build(BuildContext context) {
    final date = startDate?.add(Duration(days: day.day - 1));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Text(
            'День ${day.day}${date == null ? '' : ' · ${_dateLabel(date)}'}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        for (final event in day.events)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: SizedBox(
              width: 48,
              child: Text(
                event.kind == 'overnight_needed' ? 'Ночь' : event.timeLabel,
              ),
            ),
            title: Text(event.title),
            subtitle: event.durationMinutes > 0
                ? Text('${event.durationMinutes} мин')
                : null,
            trailing: Icon(switch (event.kind) {
              'meal_break' => Icons.restaurant_outlined,
              'overnight_needed' => Icons.hotel_outlined,
              'travel' => Icons.route_outlined,
              'rest' => Icons.coffee_outlined,
              _ => Icons.place_outlined,
            }),
          ),
      ],
    );
  }
}
