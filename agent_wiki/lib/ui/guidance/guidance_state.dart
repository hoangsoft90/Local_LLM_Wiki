import 'package:flutter/widgets.dart';

import 'guidance_models.dart';
import 'guidance_storage.dart';
import 'spotlight_overlay.dart';

/// Central state for in-app guidance (ChangeNotifier, provided at app root).
///
/// Responsibilities:
///  - Persist "seen" flags (`seen.<key>`) and "step completed"
///    (`step.<flowKey>.<stepId>`) via [GuidanceStorage].
///  - Show each onboarding flow **exactly once** per flow version — the flow
///    key embeds a version, so bumping the version re-shows it (e.g. when a
///    tour is rewritten for a release).
///  - Drive sequential steps (Step 1 → Step 2 → Finish) with Skip/Done, and
///    never re-trigger once seen (no spam on repeated actions).
class GuidanceController extends ChangeNotifier {
  GuidanceController({GuidanceStorage? storage})
      : storage = storage ?? PrefsGuidanceStorage();

  final GuidanceStorage storage;

  /// True once persisted state has been loaded (async).
  bool ready = false;

  final Set<String> _seen = {};
  final Set<String> _stepsDone = {};

  // --- active tour state ---
  bool _active = false;
  String? _flowKey;
  List<GuidanceStep> _steps = const [];
  int _currentStep = 0;
  OverlayEntry? _entry;

  // ---------- lifecycle ----------

  Future<void> init() async {
    _seen.addAll(await storage.loadKeys('seen.'));
    _stepsDone.addAll(await storage.loadKeys('step.'));
    ready = true;
    notifyListeners();
  }

  // ---------- seen flags ----------

  bool isSeen(String key) => _seen.contains(key);

  /// Feature badges hide once the feature is seen.
  bool isFeatureSeen(String featureKey) => isSeen('feature:$featureKey');

  Future<void> markFeatureSeen(String featureKey) => markSeen('feature:$featureKey');

  Future<void> markSeen(String key) async {
    if (_seen.add(key)) {
      await storage.setFlag('seen.$key', true);
      notifyListeners();
    }
  }

  /// True when a specific step of the active flow was already completed in a
  /// previous session (persisted for analytics/resume).
  bool isStepCompleted(String flowKey, String stepId) =>
      _stepsDone.contains('$flowKey.$stepId');

  // ---------- onboarding flow ----------

  /// Pure check: would [flowId]+[version] start right now? (used by tests and
  /// by [beginOnboardingIfUnseen]).
  bool canStartOnboarding({
    required String flowId,
    required String version,
  }) {
    if (!ready || _active) return false;
    return !isSeen('onboarding:$flowId:$version');
  }

  /// Start [steps] if this flow+version was never seen and no other tour is
  /// active. Returns true when the tour was started.
  ///
  /// [version] is part of the persisted key: bump it to show the tour again.
  bool beginOnboardingIfUnseen(
    BuildContext context, {
    required String flowId,
    required String version,
    required List<GuidanceStep> steps,
  }) {
    if (!canStartOnboarding(flowId: flowId, version: version)) return false;
    if (steps.isEmpty) return false;
    _start(context, flowKey: 'onboarding:$flowId:$version', steps: steps);
    return true;
  }

  void _start(
    BuildContext context, {
    required String flowKey,
    required List<GuidanceStep> steps,
  }) {
    _flowKey = flowKey;
    _steps = steps;
    _currentStep = 0;
    _active = true;
    _entry = OverlayEntry(
      builder: (_) => _SpotlightBridge(
        step: _steps[_currentStep],
        stepIndex: _currentStep,
        totalSteps: _steps.length,
        onNext: next,
        onSkip: skip,
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_entry!);
    notifyListeners();
  }

  GuidanceStep get currentStep => _steps[_currentStep];
  bool get isActive => _active;

  /// Advance to the next step; on the last step, finish.
  void next() {
    if (!_active) return;
    if (_currentStep < _steps.length - 1) {
      // Persist the completed step so we never show it again on resume.
      storage.setFlag('step.$_flowKey.${_steps[_currentStep].id}', true);
      _stepsDone.add('$_flowKey.${_steps[_currentStep].id}');
      _currentStep++;
      _entry?.markNeedsBuild();
      notifyListeners();
    } else {
      finish();
    }
  }

  /// Skip the rest of the tour (marks the flow seen — no spam).
  void skip() => finish();

  /// Finish the tour: mark the flow seen and dismiss the overlay.
  Future<void> finish() async {
    if (!_active) return;
    final flowKey = _flowKey!;
    _active = false;
    _entry?.remove();
    _entry = null;
    _steps = const [];
    _currentStep = 0;
    await markSeen(flowKey);
    notifyListeners();
  }

  // ---------- non-tour tooltip (DisabledStateHelper) ----------

  OverlayEntry? _tooltipEntry;

  /// Show an anchored tooltip near [anchorRect] explaining a disabled state.
  /// Only one is open at a time.
  void showTooltip({
    required BuildContext context,
    required Rect anchorRect,
    required String title,
    required String body,
    String? unlockHint,
  }) {
    hideTooltip();
    _tooltipEntry = OverlayEntry(
      builder: (_) => AnchoredTooltip(
        anchorRect: anchorRect,
        title: title,
        body: body,
        unlockHint: unlockHint,
        onClose: hideTooltip,
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_tooltipEntry!);
  }

  void hideTooltip() {
    _tooltipEntry?.remove();
    _tooltipEntry = null;
  }

  @override
  void dispose() {
    _entry?.remove();
    _tooltipEntry?.remove();
    super.dispose();
  }
}

/// Thin stateless bridge used inside the OverlayEntry so the overlay widget
/// only receives plain data + callbacks (no controller dependency).
class _SpotlightBridge extends StatelessWidget {
  const _SpotlightBridge({
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

  @override      Widget build(BuildContext context) => SpotlightOverlay(
        step: step,
        stepIndex: stepIndex,
        totalSteps: totalSteps,
        onNext: onNext,
        onSkip: onSkip,
      );
}
