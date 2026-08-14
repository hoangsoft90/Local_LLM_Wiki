import 'package:flutter/material.dart';

import 'guidance_models.dart';

// ---------- geometry helpers ----------

/// Global (screen) rect of a widget identified by [key], or null when the key
/// is not attached / not laid out yet.
Rect? globalRectOf(GlobalKey key) {
  final ctx = key.currentContext;
  if (ctx == null) return null;
  final renderObject = ctx.findRenderObject();
  if (renderObject is! RenderBox || !renderObject.hasSize) return null;
  return renderObject.localToGlobal(Offset.zero) & renderObject.size;
}

/// Pick where the tooltip should go relative to [target] based on free space
/// on each side (responsive to the screen). Falls back to [TooltipPlacement.bottom]
/// (which is then clamped) when no side fits.
TooltipPlacement resolvePlacement({
  required Rect target,
  required Size tooltipSize,
  required Size screen,
  double margin = 12,
  TooltipPlacement preferred = TooltipPlacement.auto,
}) {
  if (preferred != TooltipPlacement.auto) return preferred;
  if (screen.height - target.bottom >= tooltipSize.height + margin) {
    return TooltipPlacement.bottom; // space below → drop down
  }
  if (target.top >= tooltipSize.height + margin) {
    return TooltipPlacement.top;
  }
  if (screen.width - target.right >= tooltipSize.width + margin) {
    return TooltipPlacement.right;
  }
  if (target.left >= tooltipSize.width + margin) {
    return TooltipPlacement.left;
  }
  return TooltipPlacement.bottom;
}

/// Top-left position of the tooltip for a resolved [placement], clamped inside
/// the screen so the popup is never cut off.
Offset tooltipOffset({
  required Rect target,
  required Size tooltipSize,
  required Size screen,
  required TooltipPlacement placement,
  double margin = 12,
}) {
  double left;
  double top;
  switch (placement) {
    case TooltipPlacement.bottom:
      left = target.center.dx - tooltipSize.width / 2;
      top = target.bottom + margin;
      break;
    case TooltipPlacement.top:
      left = target.center.dx - tooltipSize.width / 2;
      top = target.top - tooltipSize.height - margin;
      break;
    case TooltipPlacement.right:
      left = target.right + margin;
      top = target.center.dy - tooltipSize.height / 2;
      break;
    case TooltipPlacement.left:
      left = target.left - tooltipSize.width - margin;
      top = target.center.dy - tooltipSize.height / 2;
      break;
    case TooltipPlacement.auto:
      throw ArgumentError('tooltipOffset requires a resolved placement');
  }
  // Clamp so the popup stays fully on screen (edge cases: tooltip wider than
  // the screen, target near the corner, etc.).
  final maxLeft = screen.width - tooltipSize.width - margin;
  final maxTop = screen.height - tooltipSize.height - margin;
  left = left.clamp(margin, maxLeft > margin ? maxLeft : margin);
  top = top.clamp(margin, maxTop > margin ? maxTop : margin);
  return Offset(left, top);
}

/// Slightly padded highlight around a target so the cutout doesn't hug the
/// element, then clamped to the screen.
Rect paddedTarget(Rect target, {double pad = 12, required Size screen}) {
  final padded = Rect.fromCenter(
    center: target.center,
    width: target.width + pad * 2,
    height: target.height + pad * 2,
  );
  return Rect.fromLTRB(
    padded.left.clamp(0, screen.width),
    padded.top.clamp(0, screen.height),
    padded.right.clamp(0, screen.width),
    padded.bottom.clamp(0, screen.height),
  );
}

// ---------- shared popup visual ----------

/// The guide popup used by both the spotlight tour and the anchored tooltip.
class TooltipCard extends StatelessWidget {
  const TooltipCard({
    super.key,
    required this.title,
    required this.body,
    this.icon,
    this.stepIndicator,
    this.unlockHint,
    this.actions = const [],
  });

  final String title;
  final String body;
  final IconData? icon;
  final String? stepIndicator; // e.g. "1/3"

  /// Optional "how to enable" hint shown under the body (disabled states).
  final String? unlockHint;

  final List<Widget> actions; // Skip / Next / Done buttons

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      color: theme.colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: theme.colorScheme.primary,
                    child: Icon(icon, size: 20, color: theme.colorScheme.onPrimary),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(title,
                                style: theme.textTheme.titleSmall!
                                    .copyWith(fontWeight: FontWeight.w700)),
                          ),
                          if (stepIndicator != null)
                            Text(stepIndicator!,
                                style: theme.textTheme.labelSmall!.copyWith(
                                    color: theme.colorScheme.outline)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(body, style: theme.textTheme.bodyMedium),
                      if (unlockHint != null) ...[ // shows under the body
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.lock_open,
                                size: 14,
                                color: theme.colorScheme.primary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(unlockHint!,
                                  style: theme.textTheme.bodySmall!
                                      .copyWith(
                                          color:
                                              theme.colorScheme.primary)),
                            ),
                          ],
                        ),
                      ],
                      if (actions.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Wrap(spacing: 8, children: actions),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
