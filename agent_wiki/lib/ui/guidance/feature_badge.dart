import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'guidance_models.dart';
import 'guidance_state.dart';

/// Shows a "New" dot/label on top of an icon/button until the feature is
/// marked seen (persisted via [GuidanceController]). Wrap any widget:
///
/// ```dart
/// FeatureBadge(
///   config: const FeatureBadgeConfig(featureKey: 'inbox-flow-b'),
///   child: const Icon(Icons.inbox_outlined),
/// )
/// ```
class FeatureBadge extends StatelessWidget {
  const FeatureBadge({super.key, required this.config, required this.child});

  final FeatureBadgeConfig config;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final guidance = context.watch<GuidanceController>();
    if (guidance.isFeatureSeen(config.featureKey)) {
      return child; // feature already seen → badge gone, never spammed again
    }
    final badge = config.dotOnly ? _Dot() : _Pill(label: config.label);
    // The badge sits at the configured corner, slightly outside the child so
    // it "peeks out" (negative offsets are fine because the Stack clips none).
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        _cornerPosition(config.align, badge),
      ],
    );
  }
}

/// Position the badge at one of the four corners of the child's box.
Widget _cornerPosition(Alignment align, Widget badge) {
  switch (align) {
    case Alignment.topLeft:
      return Positioned(left: -6, top: -6, child: badge);
    case Alignment.bottomLeft:
      return Positioned(left: -6, bottom: -6, child: badge);
    case Alignment.bottomRight:
      return Positioned(right: -6, bottom: -6, child: badge);
    default: // topRight
      return Positioned(right: -6, top: -6, child: badge);
  }
}

class _Dot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: Colors.deepOrange,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.deepOrange,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
