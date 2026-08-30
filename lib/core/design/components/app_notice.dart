import 'dart:async';

import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_motion.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';

enum AppNoticeKind { info, success, error }

/// In-app notice in the app's own visual language.
///
/// Replaces Material's `SnackBar`, which floats a grey slab over the bottom
/// bar in stock Flutter styling and reads as a different product. This is an
/// overlay card near the top, so it also never covers the primary CTA at the
/// bottom of a screen.
void showAppNotice(
  BuildContext context,
  String message, {
  AppNoticeKind kind = AppNoticeKind.info,
  Duration duration = const Duration(seconds: 3),
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  _AppNoticeHost.show(
    overlay: overlay,
    message: message,
    kind: kind,
    duration: duration,
    actionLabel: actionLabel,
    onAction: onAction,
  );
}

class _AppNoticeHost {
  static OverlayEntry? _current;

  static void show({
    required OverlayState overlay,
    required String message,
    required AppNoticeKind kind,
    required Duration duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    // One notice at a time: a queue would let stale messages outlive the
    // screen that produced them.
    _dismiss();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _AppNotice(
        message: message,
        kind: kind,
        duration: duration,
        actionLabel: actionLabel,
        // The auto-dismiss timer lives in the widget's State so disposing the
        // tree cancels it; a host-owned timer outlived the tree and tripped
        // the test binding's "timer still pending" invariant.
        onDismiss: () => _remove(entry),
        onAction: onAction == null
            ? null
            : () {
                _remove(entry);
                onAction();
              },
      ),
    );
    _current = entry;
    overlay.insert(entry);
  }

  static void _remove(OverlayEntry entry) {
    if (!entry.mounted) return;
    entry.remove();
    if (identical(_current, entry)) _current = null;
  }

  static void _dismiss() {
    final entry = _current;
    if (entry != null) _remove(entry);
  }
}

class _AppNotice extends StatefulWidget {
  const _AppNotice({
    required this.message,
    required this.kind,
    required this.duration,
    required this.onDismiss,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final AppNoticeKind kind;
  final Duration duration;
  final VoidCallback onDismiss;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  State<_AppNotice> createState() => _AppNoticeState();
}

class _AppNoticeState extends State<_AppNotice>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.emphasized,
  )..forward();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, widget.onDismiss);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  (IconData, Color) get _style => switch (widget.kind) {
    AppNoticeKind.success => (
      Icons.check_circle_rounded,
      const Color(0xFF16A34A),
    ),
    AppNoticeKind.error => (Icons.error_rounded, const Color(0xFFDC2626)),
    AppNoticeKind.info => (Icons.info_rounded, AppColors.primaryInk),
  };

  @override
  Widget build(BuildContext context) {
    final (icon, accent) = _style;
    final actionLabel = widget.actionLabel;
    final onAction = widget.onAction;
    final hasAction = actionLabel != null && onAction != null;
    final curved = CurvedAnimation(
      parent: _controller,
      curve: AppMotion.emphasizedCurve,
    );
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 10,
      left: 16,
      right: 16,
      // Only intercept touches when there is something to tap: an undo
      // affordance must stay reachable, but a plain notice must not block
      // the UI underneath it.
      child: IgnorePointer(
        ignoring: !hasAction,
        child: FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.35),
              end: Offset.zero,
            ).animate(curved),
            child: Material(
              color: AppColors.elevatedSurface,
              borderRadius: BorderRadius.circular(18),
              elevation: 10,
              shadowColor: const Color(0x33000000),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: AppTypography.settingsRowTitle.copyWith(
                          fontSize: 13.5,
                          height: 1.35,
                        ),
                      ),
                    ),
                    if (hasAction) ...[
                      const SizedBox(width: 8),
                      TextButton(onPressed: onAction, child: Text(actionLabel)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
