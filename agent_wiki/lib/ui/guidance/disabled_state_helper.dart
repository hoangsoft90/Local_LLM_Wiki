import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'guidance_geometry.dart';
import 'guidance_models.dart';
import 'guidance_state.dart';

/// Wraps a control that may be disabled. When the control is disabled and the
/// user taps it, a short anchored tooltip explains WHY it is disabled and the
/// condition that unlocks it. When enabled, taps pass straight through to the
/// wrapped child (no interception).
///
/// ```dart
/// DisabledStateHelper(
///   enabled: hasText,
///   config: const DisabledStateConfig(
///     reason: 'The question is empty.',
///     unlockHint: 'Type a question to enable Ask.',
///   ),
///   child: IconButton.filled(onPressed: hasText ? _ask : null, ...),
/// )
/// ```
class DisabledStateHelper extends StatefulWidget {
  const DisabledStateHelper({
    super.key,
    required this.enabled,
    required this.config,
    required this.child,
  });

  /// Whether the wrapped control is currently usable. When false, taps show
  /// the explanation instead of (nothing).
  final bool enabled;

  final DisabledStateConfig config;
  final Widget child;

  @override
  State<DisabledStateHelper> createState() => _DisabledStateHelperState();
}

class _DisabledStateHelperState extends State<DisabledStateHelper> {
  // Stable key so the child is never remounted by rebuilds.
  final GlobalKey _anchorKey = GlobalKey();

  void _onPointerDown(PointerDownEvent event) {
    // Never intercept when the control works normally.
    if (widget.enabled) return;
    final rect = globalRectOf(_anchorKey);
    if (rect == null) return;
    // Defer the overlay insert out of the pointer-dispatch phase (inserting
    // focus widgets mid-gesture trips Flutter's focus assertions in tests).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final guidance = context.read<GuidanceController>();
      guidance.showTooltip(
        context: context,
        anchorRect: rect,
        title: widget.config.title,
        body: widget.config.reason,
        unlockHint: widget.config.unlockHint,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      child: KeyedSubtree(key: _anchorKey, child: widget.child),
    );
  }
}
