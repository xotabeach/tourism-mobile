import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/features/route_match/domain/route_match_models.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_builder_design_tokens.dart';

/// Structured proposal card for AI chat (before draft / create).
///
/// Follows design-spec-travel-agent.md screens 2/3: photo header with rating
/// badge + arrow, dark tag chips, a params block, and actions.
/// Renders allowlisted fields only — never HTML / WebView.
class ChatRouteProposalCard extends StatelessWidget {
  const ChatRouteProposalCard({
    required this.card,
    this.onCreate,
    this.onSaveDraft,
    this.onRefine,
    this.onRebuild,
    this.onViewMap,
    this.onPointEdit,
    super.key,
  });

  final RouteProposalCardData card;
  final VoidCallback? onCreate;
  final VoidCallback? onSaveDraft;
  final VoidCallback? onRefine;
  final VoidCallback? onRebuild;
  final VoidCallback? onViewMap;
  final void Function(String pointId)? onPointEdit;

  @override
  Widget build(BuildContext context) {
    if (card.cardVariant == RouteProposalCardVariant.assembled) {
      return _AssembledProposalCard(
        card: card,
        onCreate: onCreate,
        onSaveDraft: onSaveDraft,
        onRefine: onRefine,
        onRebuild: onRebuild,
        onViewMap: onViewMap,
        onPointEdit: onPointEdit,
      );
    }
    return _CompactProposalCard(
      card: card,
      onCreate: onCreate,
      onSaveDraft: onSaveDraft,
      onRefine: onRefine,
      onViewMap: onViewMap,
    );
  }
}

class _CompactProposalCard extends StatelessWidget {
  const _CompactProposalCard({
    required this.card,
    this.onCreate,
    this.onSaveDraft,
    this.onRefine,
    this.onViewMap,
  });

  final RouteProposalCardData card;
  final VoidCallback? onCreate;
  final VoidCallback? onSaveDraft;
  final VoidCallback? onRefine;
  final VoidCallback? onViewMap;

  @override
  Widget build(BuildContext context) {
    final hours = card.durationMinutes ~/ 60;
    final mins = card.durationMinutes % 60;
    final durationLabel = hours > 0
        ? (mins > 0 ? '$hours ч $mins мин' : '$hours ч')
        : '$mins мин';
    final distanceLabel = card.distanceKm != null
        ? '${card.distanceKm!.toStringAsFixed(1)} км'
        : null;

    return Material(
      color: AppColors.elevatedSurface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (card.coverUrl != null && card.coverUrl!.isNotEmpty)
            AspectRatio(
              aspectRatio: 16 / 7,
              child: CatalogRoutePreviewHeader(
                title: card.title,
                coverUrl: card.coverUrl,
                rating: card.rating,
                distanceKm: card.distanceKm,
                localityLabel: card.localityLabel,
                onOpen: onViewMap,
              ),
            )
          else
            ColoredBox(
              color: AppColors.controlSurface,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.sectionTitle.copyWith(fontSize: 17),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _MetaPill(
                          icon: Icons.place_outlined,
                          label: '${card.stopsCount} точек',
                        ),
                        const SizedBox(width: 8),
                        _MetaPill(
                          icon: Icons.schedule_rounded,
                          label: durationLabel,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: _ProposalDetailsSection(
              card: card,
              distanceLabel: distanceLabel,
              onCreate: onCreate,
              onSaveDraft: onSaveDraft,
              onRefine: onRefine,
              stackedActions: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _AssembledProposalCard extends StatefulWidget {
  const _AssembledProposalCard({
    required this.card,
    this.onCreate,
    this.onSaveDraft,
    this.onRefine,
    this.onRebuild,
    this.onViewMap,
    this.onPointEdit,
  });

  final RouteProposalCardData card;
  final VoidCallback? onCreate;
  final VoidCallback? onSaveDraft;
  final VoidCallback? onRefine;
  final VoidCallback? onRebuild;
  final VoidCallback? onViewMap;
  final void Function(String pointId)? onPointEdit;

  @override
  State<_AssembledProposalCard> createState() => _AssembledProposalCardState();
}

class _AssembledProposalCardState extends State<_AssembledProposalCard> {
  late final PageController _galleryController;
  int _galleryPage = 0;

  @override
  void initState() {
    super.initState();
    _galleryController = PageController();
  }

  @override
  void dispose() {
    _galleryController.dispose();
    super.dispose();
  }

  List<String> get _galleryImages {
    final urls = widget.card.galleryUrls.take(4).toList(growable: false);
    if (urls.isNotEmpty) {
      return urls;
    }
    final cover = widget.card.coverUrl;
    return cover != null && cover.isNotEmpty ? [cover] : const [];
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final distanceLabel = card.distanceKm != null
        ? '${card.distanceKm!.toStringAsFixed(1)} км'
        : null;
    final gallery = _galleryImages;

    return Material(
      color: AppColors.elevatedSurface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (gallery.isNotEmpty)
            AspectRatio(
              aspectRatio: 16 / 7,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    controller: _galleryController,
                    itemCount: gallery.length,
                    onPageChanged: (index) =>
                        setState(() => _galleryPage = index),
                    itemBuilder: (context, index) {
                      return Image.network(
                        gallery[index],
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const ColoredBox(color: AppColors.controlSurface),
                      );
                    },
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0x55000000)],
                        stops: [0.45, 1],
                      ),
                    ),
                  ),
                  if (card.rating != null)
                    Positioned(
                      left: 10,
                      top: 10,
                      child: RoutePreviewRatingBadge(rating: card.rating!),
                    ),
                  if (gallery.length > 1)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 8,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < gallery.length; i++) ...[
                            if (i > 0) const SizedBox(width: 5),
                            Container(
                              width: i == _galleryPage ? 7 : 5,
                              height: i == _galleryPage ? 7 : 5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i == _galleryPage
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            )
          else if (card.coverUrl != null && card.coverUrl!.isNotEmpty)
            AspectRatio(
              aspectRatio: 16 / 7,
              child: CatalogRoutePreviewHeader(
                title: card.title,
                coverUrl: card.coverUrl,
                rating: card.rating,
                distanceKm: card.distanceKm,
                localityLabel: card.localityLabel,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: RouteBuilderDesignTokens.rubik(
                    fontSize: 18,
                    weight: FontWeight.w700,
                    color: RouteBuilderDesignTokens.textPrimary,
                    height: 1.15,
                  ),
                ),
                if (card.startLabel != null) ...[
                  const SizedBox(height: 12),
                  _PointEditRow(
                    label: card.startLabel!,
                    subtitle: card.startSubtitle,
                    onTap: widget.onPointEdit == null
                        ? null
                        : () => widget.onPointEdit!('start'),
                  ),
                ],
                if (card.finishLabel != null) ...[
                  const SizedBox(height: 8),
                  _PointEditRow(
                    label: card.finishLabel!,
                    subtitle: card.finishSubtitle,
                    onTap: widget.onPointEdit == null
                        ? null
                        : () => widget.onPointEdit!('finish'),
                  ),
                ],
                if (card.locations.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Локации собранного маршрута:',
                    style: RouteBuilderDesignTokens.rubik(
                      fontSize: 14,
                      weight: FontWeight.w600,
                      color: RouteBuilderDesignTokens.textPrimary,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final location in card.locations) ...[
                    _LocationRow(
                      index: location.index,
                      title: location.title,
                      subtitle: location.subtitle,
                      onTap: widget.onPointEdit == null
                          ? null
                          : () => widget.onPointEdit!(location.id),
                    ),
                    const SizedBox(height: 6),
                  ],
                ],
                if (widget.onViewMap != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: widget.onViewMap,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: RouteBuilderDesignTokens.primaryBlue,
                      side: const BorderSide(
                        color: RouteBuilderDesignTokens.primaryBlue,
                      ),
                      minimumSize: const Size.fromHeight(42),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Посмотреть на карте'),
                  ),
                ],
                const SizedBox(height: 12),
                _ProposalDetailsSection(
                  card: card,
                  distanceLabel: distanceLabel,
                  onCreate: widget.onCreate,
                  onSaveDraft: widget.onSaveDraft,
                  onRefine: widget.onRefine,
                  onRebuild: widget.onRebuild,
                  stackedActions: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProposalDetailsSection extends StatelessWidget {
  const _ProposalDetailsSection({
    required this.card,
    required this.distanceLabel,
    this.onCreate,
    this.onSaveDraft,
    this.onRefine,
    this.onRebuild,
    required this.stackedActions,
  });

  final RouteProposalCardData card;
  final String? distanceLabel;
  final VoidCallback? onCreate;
  final VoidCallback? onSaveDraft;
  final VoidCallback? onRefine;
  final VoidCallback? onRebuild;
  final bool stackedActions;

  @override
  Widget build(BuildContext context) {
    final secondaryActions = <(String label, VoidCallback onTap)>[];
    if (onSaveDraft != null) {
      secondaryActions.add(('В черновик', onSaveDraft!));
    }
    if (onRefine != null) {
      secondaryActions.add(('Уточнить', onRefine!));
    }
    if (onRebuild != null) {
      secondaryActions.add(('Собрать маршрут заново', onRebuild!));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (card.tags.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in card.tags) RoutePreviewTagChip(label: tag),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (card.budgetLabel != null ||
            card.difficultyLabel != null ||
            card.localityLabel != null ||
            distanceLabel != null) ...[
          _ParamsBlock(
            budgetLabel: card.budgetLabel,
            difficultyLabel: card.difficultyLabel,
            localityLabel: card.localityLabel,
            distanceLabel: distanceLabel,
          ),
          const SizedBox(height: 12),
        ],
        if (onCreate != null)
          FilledButton(
            onPressed: onCreate,
            style: FilledButton.styleFrom(
              backgroundColor: RouteBuilderDesignTokens.primaryBlue,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(card.primaryActionLabel),
          ),
        if (secondaryActions.isNotEmpty) ...[
          const SizedBox(height: 8),
          if (stackedActions)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < secondaryActions.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: secondaryActions[i].$2,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: RouteBuilderDesignTokens.primaryBlue,
                      side: const BorderSide(
                        color: RouteBuilderDesignTokens.primaryBlue,
                      ),
                      minimumSize: const Size.fromHeight(42),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(secondaryActions[i].$1),
                  ),
                ],
              ],
            )
          else
            Row(
              children: [
                for (var i = 0; i < secondaryActions.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: secondaryActions[i].$2,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: RouteBuilderDesignTokens.primaryBlue,
                        side: const BorderSide(
                          color: RouteBuilderDesignTokens.primaryBlue,
                        ),
                        minimumSize: const Size.fromHeight(42),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(secondaryActions[i].$1),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ],
    );
  }
}

class _PointEditRow extends StatelessWidget {
  const _PointEditRow({required this.label, this.subtitle, this.onTap});

  final String label;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: RouteBuilderDesignTokens.fieldBackground,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RouteBuilderDesignTokens.rubik(
                        fontSize: 14,
                        weight: FontWeight.w600,
                        color: RouteBuilderDesignTokens.textPrimary,
                        height: 1.1,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RouteBuilderDesignTokens.rubik(
                          fontSize: 12,
                          color: RouteBuilderDesignTokens.textSecondary,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: RouteBuilderDesignTokens.textSecondary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.index,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final int index;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: RouteBuilderDesignTokens.primaryBlue.withValues(
                    alpha: 0.12,
                  ),
                ),
                child: Text(
                  '$index',
                  style: RouteBuilderDesignTokens.rubik(
                    fontSize: 12,
                    weight: FontWeight.w600,
                    color: RouteBuilderDesignTokens.primaryBlue,
                    height: 1.0,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RouteBuilderDesignTokens.rubik(
                        fontSize: 14,
                        color: RouteBuilderDesignTokens.textPrimary,
                        height: 1.1,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RouteBuilderDesignTokens.rubik(
                          fontSize: 12,
                          color: RouteBuilderDesignTokens.textSecondary,
                          height: 1.1,
                        ),
                      ),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: RouteBuilderDesignTokens.textSecondary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class RoutePreviewRatingBadge extends StatelessWidget {
  const RoutePreviewRatingBadge({required this.rating, super.key});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 14, color: Color(0xFFFFC107)),
          const SizedBox(width: 4),
          Text(
            rating.toStringAsFixed(1),
            style: RouteBuilderDesignTokens.rubik(
              fontSize: 13,
              weight: FontWeight.w600,
              color: Colors.white,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class RoutePreviewRoundButton extends StatelessWidget {
  const RoutePreviewRoundButton({
    required this.icon,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.85),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, size: 17, color: const Color(0xFF33343A)),
        ),
      ),
    );
  }
}

class RoutePreviewTagChip extends StatelessWidget {
  const RoutePreviewTagChip({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF33343A),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: RouteBuilderDesignTokens.rubik(
          fontSize: 12,
          color: Colors.white,
          height: 1.0,
        ),
      ),
    );
  }
}

class _ParamsBlock extends StatelessWidget {
  const _ParamsBlock({
    this.budgetLabel,
    this.difficultyLabel,
    this.localityLabel,
    this.distanceLabel,
  });

  final String? budgetLabel;
  final String? difficultyLabel;
  final String? localityLabel;
  final String? distanceLabel;

  @override
  Widget build(BuildContext context) {
    final rows = <_ParamRowData>[
      if (budgetLabel != null)
        _ParamRowData(
          Icons.account_balance_wallet_outlined,
          'Минимальный бюджет:',
          budgetLabel!,
        ),
      if (difficultyLabel != null)
        _ParamRowData(Icons.bolt_rounded, 'Сложность:', difficultyLabel!),
      if (localityLabel != null)
        _ParamRowData(Icons.landscape_outlined, 'Маршрут:', localityLabel!),
      if (distanceLabel != null)
        _ParamRowData(Icons.place_outlined, 'Расстояние:', distanceLabel!),
    ];
    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final row in rows) ...[
          if (row != rows.first) const SizedBox(height: 10),
          Row(
            children: [
              Icon(row.icon, size: 16, color: const Color(0xFF33343A)),
              const SizedBox(width: 8),
              Text(
                row.label,
                style: RouteBuilderDesignTokens.rubik(
                  fontSize: 14,
                  color: const Color(0xFF3A3A3C),
                  height: 1.1,
                ),
              ),
              const Spacer(),
              Text(
                row.value,
                style: RouteBuilderDesignTokens.rubik(
                  fontSize: 14,
                  weight: FontWeight.w700,
                  color: const Color(0xFF1C1C1E),
                  height: 1.1,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ParamRowData {
  const _ParamRowData(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({this.icon, required this.label});

  final IconData? icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    const foreground = RouteBuilderDesignTokens.textPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: RouteBuilderDesignTokens.rubik(
              fontSize: 12,
              weight: FontWeight.w600,
              color: foreground,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared photo header for catalog carousel cards and compact proposal cards.
class CatalogRoutePreviewHeader extends StatelessWidget {
  const CatalogRoutePreviewHeader({
    required this.title,
    this.coverUrl,
    this.rating,
    this.distanceKm,
    this.localityLabel,
    this.tags = const [],
    this.budgetLabel,
    this.difficultyLabel,
    this.onOpen,
    super.key,
  });

  final String title;
  final String? coverUrl;
  final double? rating;
  final double? distanceKm;
  final String? localityLabel;
  final List<String> tags;
  final String? budgetLabel;
  final String? difficultyLabel;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final distanceLabel = distanceKm != null
        ? '${distanceKm!.toStringAsFixed(1)} км'
        : null;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (coverUrl != null && coverUrl!.isNotEmpty)
          Image.network(
            coverUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                const ColoredBox(color: AppColors.controlSurface),
          )
        else
          const ColoredBox(color: AppColors.controlSurface),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Color(0x77000000)],
              stops: [0.3, 1],
            ),
          ),
        ),
        if (rating != null)
          Positioned(
            left: 10,
            top: 10,
            child: RoutePreviewRatingBadge(rating: rating!),
          ),
        if (onOpen != null)
          Positioned(
            right: 10,
            top: 10,
            child: RoutePreviewRoundButton(
              icon: Icons.arrow_forward,
              onTap: onOpen!,
            ),
          ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: RouteBuilderDesignTokens.rubik(
                  fontSize: 19,
                  weight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.15,
                ),
              ),
              if (localityLabel != null || distanceLabel != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (localityLabel != null) ...[
                      const Icon(
                        Icons.place_outlined,
                        size: 13,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          localityLabel!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: RouteBuilderDesignTokens.rubik(
                            fontSize: 12,
                            color: Colors.white,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ],
                    if (distanceLabel != null) ...[
                      const SizedBox(width: 14),
                      const Icon(
                        Icons.route_outlined,
                        size: 13,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        distanceLabel,
                        style: RouteBuilderDesignTokens.rubik(
                          fontSize: 12,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
              if (tags.isNotEmpty ||
                  budgetLabel != null ||
                  difficultyLabel != null) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final tag in tags) RoutePreviewTagChip(label: tag),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
