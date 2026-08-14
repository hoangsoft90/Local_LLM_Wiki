import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'guidance_geometry.dart';
import 'guidance_models.dart';

/// Full-screen onboarding overlay: dims the background, cuts a rounded
/// highlight around the target element and shows an attached guide popup with
/// Skip / Next / Done. Tooltip position is resolved from the target's global
/// rect and clamped to the screen (responsive on any device).
class SpotlightOverlay extends StatefulWidget {
  const SpotlightOverlay({
    super.key,
    required this.step,
    required this.stepIndex,
    required this.totalSteps,
    required this.onNext,
    required this.onSkip,
  });

  final GuidanceStep step;
  final int stepIndex;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  State<SpotlightOverlay> createState() => _SpotlightOverlayState();
}

class _SpotlightOverlayState extends State<SpotlightOverlay> {
  static const double _margin = 12;
  static const double _tooltipMaxWidth = 320;

  final GlobalKey _tooltipKey = GlobalKey();
  Rect? _target;
  Size? _tooltipSize;

  @override
  void initState() {
    super.initState();
    _resolveAndMeasure();
  }

  @override
  void didUpdateWidget(SpotlightOverlay old) {
    super.didUpdateWidget(old);
    // New step → new content → re-measure the tooltip before positioning it.
    if (old.step.id != widget.step.id) {
      _tooltipSize = null;
      _resolveAndMeasure();
    }
  }

  void _resolveAndMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // The target key must be laid out (HomeScreen quick actions).
      setState(() => _target = globalRectOf(widget.step.targetKey));
      WidgetsBinding.instance.addPostFrameCallback((_) => _measureTooltip());
    });
  }

  void _measureTooltip() {
    final ctx = _tooltipKey.currentContext;
    if (ctx == null || !mounted) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    setState(() => _tooltipSize = box.size);
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final tooltipWidth =
        math.min(screen.width - _margin * 2, _tooltipMaxWidth);

    final Widget tooltip = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: tooltipWidth),
      child: TooltipCard(
        key: _tooltipKey,
        title: widget.step.title,
        body: widget.step.body,
        icon: widget.step.icon,
        stepIndicator: '${widget.stepIndex + 1}/${widget.totalSteps}',
        actions: [
          if (widget.totalSteps > 1)
            TextButton(
                onPressed: widget.onSkip, child: const Text('Skip')),
          FilledButton(
            onPressed: widget.onNext,
            child: Text(widget.stepIndex == widget.totalSteps - 1
                ? 'Done'
                : 'Next'),
          ),
        ],
      ),
    );

    // Widget position: measured first (invisible at origin), then placed.
    late final Widget placed;
    final target = _target;
    final size = _tooltipSize;
    if (target == null || size == null) {
      placed = Positioned(
        left: 0,
        top: 0,
        width: tooltipWidth,
        child: IgnorePointer(
            child: Opacity(opacity: 0, child: tooltip)), // measure pass
      );
    } else {
      final placement = resolvePlacement(
          target: target, tooltipSize: size, screen: screen,
          preferred: widget.step.placement);
      final offset = tooltipOffset(
          target: target,
          tooltipSize: size,
          screen: screen,
          placement: placement);
      placed = Positioned(
        left: offset.dx,
        top: offset.dy,
        width: tooltipWidth,
        child: tooltip,
      );
    }

    return Stack(
      children: [
        // Absorb taps so the app underneath can't react during the tour.
        Positioned.fill(
          child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () {}),
        ),
        if (target != null)
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: 1,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: CustomPaint(
                painter: _SpotlightPainter(
                  target: paddedTarget(target, screen: screen),
                  dimColor: Colors.black.withValues(alpha: 0.72),
                  radius: 14,
                ),
              ),
            ),
          ),
        placed,
      ],
    );
  }
}

/// Paints a dim layer over the whole screen with a rounded "hole" around the
/// target (even-odd fill: screen rect minus cutout).
class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({
    required this.target,
    required this.dimColor,
    required this.radius,
  });

  final Rect target;
  final Color dimColor;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final screen = Offset.zero & size;
    final cutout = Path()
      ..addRRect(
          RRect.fromRectAndRadius(target, Radius.circular(radius)));
    final dim = Path()
      ..addRect(screen)
      ..addPath(cutout, Offset.zero)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(dim, Paint()..color = dimColor);
    // Light border around the highlight so the target pops.
    canvas.drawRRect(
      RRect.fromRectAndRadius(target, Radius.circular(radius)),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.target != target || old.dimColor != dimColor || old.radius != radius;
}

/// A short tooltip anchored near an arbitrary global [anchorRect] — used by
/// [DisabledStateHelper] to explain why a control is disabled. Tapping the
/// barrier closes it.
class AnchoredTooltip extends StatefulWidget {
  const AnchoredTooltip({
    super.key,
    required this.anchorRect,
    required this.title,
    required this.body,
    this.unlockHint,
    required this.onClose,
  });

  final Rect anchorRect;
  final String title;
  final String body;
  final String? unlockHint;
  final VoidCallback onClose;

  @override
  State<AnchoredTooltip> createState() => _AnchoredTooltipState();
}

class _AnchoredTooltipState extends State<AnchoredTooltip> {
  static const double _margin = 12;
  static const double _tooltipMaxWidth = 320;

  final GlobalKey _tooltipKey = GlobalKey();
  Size? _size;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _tooltipKey.currentContext;
      if (ctx == null || !mounted) return;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      setState(() => _size = box.size);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final tooltipWidth =
        math.min(screen.width - _margin * 2, _tooltipMaxWidth);

    final Widget card = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: tooltipWidth),
      child: TooltipCard(
        key: _tooltipKey,
        title: widget.title,
        body: widget.body,
        icon: Icons.info_outline,
        unlockHint: widget.unlockHint,
        actions: [
          TextButton(
              onPressed: widget.onClose, child: const Text('Got it')),
        ],
      ),
    );

    final size = _size;
    late final Widget placed;
    if (size == null) {
      placed = Positioned(
        left: 0,
        top: 0,
        width: tooltipWidth,
        child: IgnorePointer(
            child: Opacity(opacity: 0, child: card)), // measure pass
      );
    } else {
      final anchor = widget.anchorRect;
      final left = (anchor.center.dx - size.width / 2)
          .clamp(_margin, screen.width - size.width - _margin);
      // Prefer above the control; fall back below when there is no room.
      final top = anchor.top - size.height - _margin >= _margin
          ? anchor.top - size.height - _margin
          : (anchor.bottom + _margin)
              .clamp(_margin, screen.height - size.height - _margin);
      placed = Positioned(
        left: left,
        top: top,
        width: tooltipWidth,
        child: card,
      );
    }

    return Stack(
      children: [
        // Tap anywhere to dismiss.
        Positioned.fill(
          child: GestureDetector(
              behavior: HitTestBehavior.opaque, onTap: widget.onClose),
        ),
        placed,
      ],
    );
  }
}
