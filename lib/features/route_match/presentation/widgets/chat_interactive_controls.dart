import 'package:flutter/material.dart';

import 'package:tourism_mobile/features/route_match/presentation/route_builder_design_tokens.dart';
import 'package:tourism_mobile/features/route_match/presentation/route_match_widgets.dart';

typedef RoutePx = double Function(double);

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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: RouteBuilderDesignTokens.deepBlue.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(px(12)),
        border: Border.all(
          color: RouteBuilderDesignTokens.deepBlue.withValues(alpha: 0.18),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(px(12), px(10), px(12), px(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data.title,
              style: RouteBuilderDesignTokens.rubik(
                fontSize: px(14),
                color: RouteBuilderDesignTokens.deepBlue,
                height: 1.2,
              ),
            ),
            SizedBox(height: px(6)),
            Text(
              data.body,
              style: RouteBuilderDesignTokens.rubik(
                fontSize: px(13),
                color: RouteBuilderDesignTokens.deepBlue.withValues(
                  alpha: 0.85,
                ),
                height: 1.35,
              ),
            ),
            SizedBox(height: px(8)),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onAccept,
                child: Text(
                  data.acceptLabel,
                  style: RouteBuilderDesignTokens.rubik(
                    fontSize: px(13),
                    color: RouteBuilderDesignTokens.deepBlue,
                    height: 1.1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
  Widget build(BuildContext context) {
    final unit = widget.data.unit ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${widget.data.label}: ${_value.round()}$unit',
          style: RouteBuilderDesignTokens.rubik(
            fontSize: widget.px(13),
            color: RouteBuilderDesignTokens.deepBlue,
            height: 1.2,
          ),
        ),
        Slider(
          min: widget.data.minValue,
          max: widget.data.maxValue,
          divisions:
              ((widget.data.maxValue - widget.data.minValue) /
                      (widget.data.step <= 0 ? 1 : widget.data.step))
                  .round()
                  .clamp(1, 100),
          value: _value.clamp(widget.data.minValue, widget.data.maxValue),
          onChanged: (value) => setState(() => _value = value),
          onChangeEnd: (value) => widget.onCommit(widget.data.id, value),
        ),
      ],
    );
  }
}

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
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(
        data.label,
        style: RouteBuilderDesignTokens.rubik(
          fontSize: px(13),
          color: RouteBuilderDesignTokens.deepBlue,
          height: 1.2,
        ),
      ),
      value: data.value,
      onChanged: (value) => onChanged(data.id, value),
    );
  }
}
