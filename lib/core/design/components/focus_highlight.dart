import 'dart:async';

import 'package:flutter/material.dart';

/// Scrolls [child] into view once and lights it up for a moment: the
/// comment or review a notification led to (FRONTEND-74). Inactive, it is
/// just [child].
class FocusHighlight extends StatefulWidget {
  const FocusHighlight({
    required this.child,
    this.active = false,
    this.borderRadius = 18,
    super.key,
  });

  final Widget child;
  final bool active;
  final double borderRadius;

  static const color = Color(0x33FF9F43);
  static const hold = Duration(milliseconds: 1800);

  @override
  State<FocusHighlight> createState() => _FocusHighlightState();
}

class _FocusHighlightState extends State<FocusHighlight> {
  var _lit = false;
  var _done = false;
  Timer? _fade;

  @override
  void initState() {
    super.initState();
    if (widget.active) _schedule();
  }

  @override
  void didUpdateWidget(covariant FocusHighlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _schedule();
  }

  void _schedule() {
    if (_done) return;
    _done = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      setState(() => _lit = true);
      await Scrollable.ensureVisible(
        context,
        alignment: 0.2,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
      _fade = Timer(FocusHighlight.hold, () {
        if (mounted) setState(() => _lit = false);
      });
    });
  }

  @override
  void dispose() {
    _fade?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active && !_lit) return widget.child;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      decoration: BoxDecoration(
        color: _lit ? FocusHighlight.color : const Color(0x00FF9F43),
        borderRadius: BorderRadius.circular(widget.borderRadius),
      ),
      child: widget.child,
    );
  }
}
