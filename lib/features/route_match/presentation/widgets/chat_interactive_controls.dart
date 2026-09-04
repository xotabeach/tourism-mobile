import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/design/app_motion.dart';
import 'package:tourism_mobile/features/route_match/domain/route_match_models.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_builder_design_tokens.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_match_widgets.dart';

typedef RoutePx = double Function(double);

/// Advisory tip the user can accept with one tap.
///
/// Renders allowlisted fields only — never HTML / WebView.
class ChatRecommendationCard extends StatelessWidget {
  const ChatRecommendationCard({
    required this.px,
    required this.data,
    required this.onAccept,
    super.key,
  });

  final RoutePx px;
  final RouteChatRecommendationData data;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(px(12));
    return Semantics(
      button: true,
      label: '${data.title}. ${data.body}. ${data.acceptLabel}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onAccept,
          borderRadius: radius,
          splashColor: RouteBuilderDesignTokens.deepBlue.withValues(
            alpha: 0.08,
          ),
          highlightColor: RouteBuilderDesignTokens.deepBlue.withValues(
            alpha: 0.04,
          ),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  RouteBuilderDesignTokens.deepBlue.withValues(alpha: 0.05),
                  RouteBuilderDesignTokens.cyanBlue.withValues(alpha: 0.08),
                ],
              ),
              border: Border.all(
                color: RouteBuilderDesignTokens.deepBlue.withValues(alpha: 0.2),
                width: px(1),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(px(12), px(10), px(10), px(10)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: px(26),
                    height: px(26),
                    margin: EdgeInsets.only(top: px(1)),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RouteBuilderDesignTokens.travelPlusGradient,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.lightbulb_rounded,
                        size: 15,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(width: px(10)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.title,
                          style: RouteBuilderDesignTokens.rubik(
                            fontSize: px(14),
                            weight: FontWeight.w600,
                            color: RouteBuilderDesignTokens.deepBlue,
                            height: 1.2,
                          ),
                        ),
                        SizedBox(height: px(5)),
                        Text(
                          data.body,
                          style: RouteBuilderDesignTokens.rubik(
                            fontSize: px(13),
                            color: RouteBuilderDesignTokens.textPrimary,
                            height: 1.35,
                          ),
                        ),
                        SizedBox(height: px(8)),
                        _RecommendationCta(
                          px: px,
                          label: data.acceptLabel,
                          onAccept: onAccept,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecommendationCta extends StatelessWidget {
  const _RecommendationCta({
    required this.px,
    required this.label,
    required this.onAccept,
  });

  final RoutePx px;
  final String label;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: RouteBuilderDesignTokens.deepBlue.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(px(999)),
      child: InkWell(
        onTap: onAccept,
        borderRadius: BorderRadius.circular(px(999)),
        highlightColor: RouteBuilderDesignTokens.deepBlue.withValues(
          alpha: 0.14,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: px(12), vertical: px(6)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: RouteBuilderDesignTokens.rubik(
                  fontSize: px(13),
                  weight: FontWeight.w600,
                  color: RouteBuilderDesignTokens.deepBlue,
                  height: 1.0,
                ),
              ),
              SizedBox(width: px(5)),
              Icon(
                Icons.arrow_forward_rounded,
                size: px(15),
                color: RouteBuilderDesignTokens.deepBlue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Numeric slider control with a live value bubble above the thumb.
class ChatSliderControl extends StatefulWidget {
  const ChatSliderControl({
    required this.px,
    required this.data,
    required this.onCommit,
    super.key,
  });

  final RoutePx px;
  final RouteChatSliderData data;
  final void Function(String id, double value) onCommit;

  @override
  State<ChatSliderControl> createState() => _ChatSliderControlState();
}

class _ChatSliderControlState extends State<ChatSliderControl> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.data.value ?? widget.data.minValue;
  }

  @override
  void didUpdateWidget(covariant ChatSliderControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data.value != null &&
        widget.data.value != oldWidget.data.value) {
      _value = widget.data.value!;
    }
  }

  double get _snappedValue {
    final step = widget.data.step <= 0 ? 1.0 : widget.data.step;
    final snapped = (_value / step).round() * step;
    if (snapped.isNaN || snapped.isInfinite) {
      return _value;
    }
    return snapped.clamp(widget.data.minValue, widget.data.maxValue).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final px = widget.px;
    final unit = widget.data.unit ?? '';
    final divisions =
        ((widget.data.maxValue - widget.data.minValue) /
                (widget.data.step <= 0 ? 1 : widget.data.step))
            .round()
            .clamp(1, 100);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.data.label,
              style: RouteBuilderDesignTokens.rubik(
                fontSize: px(13),
                weight: FontWeight.w500,
                color: RouteBuilderDesignTokens.textPrimary,
                height: 1.2,
              ),
            ),
            AnimatedContainer(
              duration: AppMotion.normal,
              curve: AppMotion.standard,
              padding: EdgeInsets.symmetric(horizontal: px(8), vertical: px(3)),
              decoration: BoxDecoration(
                color: RouteBuilderDesignTokens.deepBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(px(999)),
              ),
              child: Text(
                '${_snappedValue.round()}$unit',
                style: RouteBuilderDesignTokens.rubik(
                  fontSize: px(13),
                  weight: FontWeight.w700,
                  color: RouteBuilderDesignTokens.deepBlue,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: px(2)),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: px(4),
            activeTrackColor: RouteBuilderDesignTokens.primaryBlue,
            inactiveTrackColor: RouteBuilderDesignTokens.fieldBackground,
            thumbColor: Colors.white,
            overlayColor: RouteBuilderDesignTokens.primaryBlue.withValues(
              alpha: 0.12,
            ),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
            valueIndicatorColor: RouteBuilderDesignTokens.primaryBlue,
          ),
          child: SizedBox(
            height: px(32),
            child: Slider(
              min: widget.data.minValue,
              max: widget.data.maxValue,
              divisions: divisions,
              value: _value.clamp(widget.data.minValue, widget.data.maxValue),
              onChanged: (value) => setState(() => _value = value),
              onChangeEnd: (value) =>
                  widget.onCommit(widget.data.id, _snappedValue),
            ),
          ),
        ),
      ],
    );
  }
}

/// Groups sliders + toggles from one agent message behind a single
/// «Подтвердить» action instead of sending a chat turn per drag/tap — each
/// control only updates local pending state until confirmed.
class ChatControlsGroup extends StatefulWidget {
  const ChatControlsGroup({
    required this.px,
    required this.sliders,
    required this.toggles,
    required this.onConfirm,
    super.key,
  });

  final RoutePx px;
  final List<RouteChatSliderData> sliders;
  final List<RouteChatToggleData> toggles;
  final void Function(Map<String, Object> values) onConfirm;

  @override
  State<ChatControlsGroup> createState() => _ChatControlsGroupState();
}

class _ChatControlsGroupState extends State<ChatControlsGroup> {
  late final Map<String, Object> _values;
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    _values = {
      for (final slider in widget.sliders)
        slider.id: slider.value ?? slider.minValue,
      for (final toggle in widget.toggles) toggle.id: toggle.value,
    };
  }

  void _confirm() {
    if (_confirmed) {
      return;
    }
    setState(() => _confirmed = true);
    widget.onConfirm(Map<String, Object>.from(_values));
  }

  @override
  Widget build(BuildContext context) {
    final px = widget.px;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final slider in widget.sliders) ...[
          ChatSliderControl(
            px: px,
            data: slider,
            onCommit: _confirmed
                ? (_, _) {}
                : (id, value) => setState(() => _values[id] = value),
          ),
          SizedBox(height: px(10)),
        ],
        for (final toggle in widget.toggles) ...[
          ChatToggleControl(
            px: px,
            data: RouteChatToggleData(
              id: toggle.id,
              label: toggle.label,
              value: _values[toggle.id] == true,
            ),
            onChanged: _confirmed
                ? (_, _) {}
                : (id, value) => setState(() => _values[id] = value),
          ),
          SizedBox(height: px(8)),
        ],
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _confirmed ? null : _confirm,
            style: FilledButton.styleFrom(
              backgroundColor: RouteBuilderDesignTokens.primaryBlue,
              disabledBackgroundColor: RouteBuilderDesignTokens.primaryBlue
                  .withValues(alpha: 0.4),
              minimumSize: Size.fromHeight(px(40)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(px(10)),
              ),
              textStyle: RouteBuilderDesignTokens.rubik(
                fontSize: px(14),
                weight: FontWeight.w600,
                height: 1.1,
              ),
            ),
            child: Text(_confirmed ? 'Учтено' : 'Подтвердить'),
          ),
        ),
      ],
    );
  }
}

/// Boolean toggle with a gradient track and animated thumb.
class ChatToggleControl extends StatelessWidget {
  const ChatToggleControl({
    required this.px,
    required this.data,
    required this.onChanged,
    super.key,
  });

  final RoutePx px;
  final RouteChatToggleData data;
  final void Function(String id, bool value) onChanged;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(px(12));
    return Semantics(
      toggled: data.value,
      label: data.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onChanged(data.id, !data.value),
          borderRadius: radius,
          highlightColor: RouteBuilderDesignTokens.deepBlue.withValues(
            alpha: 0.05,
          ),
          child: Ink(
            padding: EdgeInsets.symmetric(horizontal: px(10), vertical: px(9)),
            decoration: BoxDecoration(
              color: data.value
                  ? RouteBuilderDesignTokens.deepBlue.withValues(alpha: 0.06)
                  : RouteBuilderDesignTokens.surface,
              borderRadius: radius,
              border: Border.all(
                color: data.value
                    ? RouteBuilderDesignTokens.deepBlue.withValues(alpha: 0.4)
                    : RouteBuilderDesignTokens.lightBorder,
                width: px(1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    data.label,
                    style: RouteBuilderDesignTokens.rubik(
                      fontSize: px(14),
                      color: RouteBuilderDesignTokens.textPrimary,
                      height: 1.1,
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: AppMotion.fast,
                  curve: AppMotion.standard,
                  width: px(44),
                  height: px(26),
                  padding: EdgeInsets.all(px(3)),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(px(13)),
                    gradient: data.value
                        ? RouteBuilderDesignTokens.travelPlusGradient
                        : null,
                    color: data.value
                        ? null
                        : RouteBuilderDesignTokens.fieldBackground,
                  ),
                  child: AnimatedAlign(
                    duration: AppMotion.fast,
                    curve: AppMotion.standard,
                    alignment: data.value
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      width: px(20),
                      height: px(20),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: Icon(
                        data.value ? Icons.check_rounded : Icons.close_rounded,
                        size: px(13),
                        color: data.value
                            ? RouteBuilderDesignTokens.deepBlue
                            : RouteBuilderDesignTokens.textSecondary,
                      ),
                    ),
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

/// Выпадающий список в пузыре агента (макет «Подбор маршрута 4»).
///
/// Все размеры замерены по экспорту (590px на 393pt, делитель 1.5013):
/// поле 38, рамка и разделитель #E9E9E9, разделитель НЕ во всю ширину —
/// отступ ~11 слева и справа, скроллбар шириной 1.33 с подложкой #E8F0F9
/// и синим бегунком. Список ограничен по высоте и прокручивается: при
/// десяти городах он иначе выпихивает композер за экран.
class ChatSelectControl extends StatefulWidget {
  const ChatSelectControl({
    required this.px,
    required this.data,
    required this.onSelected,
    super.key,
  });

  final RoutePx px;
  final RouteChatSelectData data;
  final void Function(String value) onSelected;

  @override
  State<ChatSelectControl> createState() => _ChatSelectControlState();
}

class _ChatSelectControlState extends State<ChatSelectControl> {
  bool _open = false;
  String? _value;

  @override
  void initState() {
    super.initState();
    _value = widget.data.value;
  }

  String get _headline {
    final value = _value;
    if (value == null) {
      return widget.data.placeholder;
    }
    return widget.data.options
        .firstWhere(
          (option) => option.value == value,
          orElse: () => SelectOptionItem(value: value, label: value),
        )
        .label;
  }

  @override
  Widget build(BuildContext context) {
    final px = widget.px;
    // Свой Material: внутри InkWell, а пузырь агента рисуется DecoratedBox'ом
    // и Material-предка не даёт — без этого контрол падает на debugCheckHasMaterial.
    return Material(
      color: RouteBuilderDesignTokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(px(8)),
        side: const BorderSide(color: RouteBuilderDesignTokens.chatHairline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            expanded: _open,
            label: widget.data.label,
            child: InkWell(
              key: const ValueKey('chat-select-header'),
              onTap: () => setState(() => _open = !_open),
              borderRadius: BorderRadius.circular(px(8)),
              child: SizedBox(
                height: px(38),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: px(14)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _headline,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: RouteBuilderDesignTokens.rubik(
                            fontSize: px(15),
                            color: RouteBuilderDesignTokens.primaryBlue,
                            height: 1.1,
                          ),
                        ),
                      ),
                      Icon(
                        _open
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: px(20),
                        color: RouteBuilderDesignTokens.primaryBlue,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_open)
            _SelectOptionList(
              px: px,
              options: widget.data.options,
              selected: _value,
              onTap: (value) {
                setState(() {
                  _value = value;
                  _open = false;
                });
                widget.onSelected(value);
              },
            ),
        ],
      ),
    );
  }
}

class _SelectOptionList extends StatelessWidget {
  const _SelectOptionList({
    required this.px,
    required this.options,
    required this.selected,
    required this.onTap,
  });

  final RoutePx px;
  final List<SelectOptionItem> options;
  final String? selected;
  final void Function(String value) onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Разделитель под шапкой с отступами по краям, а не во всю ширину.
      padding: EdgeInsets.symmetric(horizontal: px(11)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: px(1),
            color: RouteBuilderDesignTokens.chatHairline,
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: px(214)),
            child: _ThinScrollbar(
              px: px,
              child: ListView(
                key: const ValueKey('chat-select-options'),
                shrinkWrap: true,
                padding: EdgeInsets.symmetric(vertical: px(6)),
                children: [
                  for (final option in options)
                    InkWell(
                      onTap: () => onTap(option.value),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: px(3),
                          vertical: px(9),
                        ),
                        child: Text(
                          option.label,
                          style: RouteBuilderDesignTokens.rubik(
                            fontSize: px(15),
                            weight: option.value == selected
                                ? FontWeight.w500
                                : FontWeight.w400,
                            color: RouteBuilderDesignTokens.primaryBlue,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Скроллбар-волосок: 1.33 шириной, подложка #E8F0F9, бегунок #1E71CA.
/// Материаловский `Scrollbar` сюда не подошёл — его минимальная толщина и
/// отступы заметно толще того, что в макете.
class _ThinScrollbar extends StatelessWidget {
  const _ThinScrollbar({required this.px, required this.child});

  final RoutePx px;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RawScrollbar(
      thumbVisibility: true,
      trackVisibility: true,
      thickness: px(1.33),
      radius: Radius.zero,
      thumbColor: RouteBuilderDesignTokens.primaryBlue,
      trackColor: RouteBuilderDesignTokens.chatScrollTrack,
      trackBorderColor: Colors.transparent,
      crossAxisMargin: 0,
      mainAxisMargin: px(5),
      child: child,
    );
  }
}
