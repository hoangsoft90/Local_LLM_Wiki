import 'package:flutter/material.dart';

/// Where a guide popup attaches relative to its target element.
///
/// [auto] picks the side with the most free space (see guidance_geometry).
enum TooltipPlacement { top, bottom, left, right, auto }

/// One step of a sequential onboarding tour: a target element (identified by
/// its [GlobalKey]) + the guide text shown next to it.
class GuidanceStep {
  const GuidanceStep({
    required this.id,
    required this.targetKey,
    required this.title,
    required this.body,
    this.icon = Icons.tips_and_updates_outlined,
    this.placement = TooltipPlacement.auto,
  });

  /// Stable id used to persist "step completed" — must not change between
  /// sessions or the flag is lost.
  final String id;

  /// The element to highlight. The key must be attached to a widget that is
  /// currently in the tree and laid out.
  final GlobalKey targetKey;

  final String title;
  final String body;
  final IconData icon;
  final TooltipPlacement placement;
}

/// Config for a "New" badge shown on an icon/button until the feature is seen.
class FeatureBadgeConfig {
  const FeatureBadgeConfig({
    required this.featureKey,
    this.label = 'New',
    this.dotOnly = false,
    this.align = Alignment.topRight,
  });

  /// Persisted "seen" key — bump it (e.g. `inbox-flow-b-v2`) to re-show.
  final String featureKey;
  final String label;
  final bool dotOnly;
  final Alignment align;
}

/// Config for [DisabledStateHelper]: what to explain and how to unlock.
class DisabledStateConfig {
  const DisabledStateConfig({
    required this.reason,
    this.unlockHint,
    this.title = 'Why is this disabled?',
  });

  /// Short explanation of why the control is currently disabled.
  final String reason;

  /// The condition that unlocks it (e.g. "Type a question first").
  final String? unlockHint;

  final String title;
}
