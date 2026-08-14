import 'package:agent_wiki/ui/guidance/disabled_state_helper.dart';
import 'package:agent_wiki/ui/guidance/feature_badge.dart';
import 'package:agent_wiki/ui/guidance/guidance_geometry.dart';
import 'package:agent_wiki/ui/guidance/guidance_models.dart';
import 'package:agent_wiki/ui/guidance/guidance_state.dart';
import 'package:agent_wiki/ui/guidance/guidance_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  group('GuidanceController (logic)', () {
    test('shows once per flow version, never re-triggers after seen', () async {
      final storage = MemoryGuidanceStorage();
      final c = GuidanceController(storage: storage);
      await c.init();
      expect(c.ready, isTrue);

      // Fresh flow → can start.
      expect(
        c.canStartOnboarding(flowId: 'first-run', version: 'v1'),
        isTrue,
      );

      // Simulate the tour having been completed.
      await c.markSeen('onboarding:first-run:v1');

      // Same session: no re-show.
      expect(
        c.canStartOnboarding(flowId: 'first-run', version: 'v1'),
        isFalse,
      );

      // Simulate a NEW app launch (fresh controller, same persisted storage).
      final c2 = GuidanceController(storage: storage);
      await c2.init();
      expect(
        c2.canStartOnboarding(flowId: 'first-run', version: 'v1'),
        isFalse,
        reason: 'seen flag persisted across sessions — no spam',
      );

      // Version bump (tour rewritten for a release) → shows again.
      expect(
        c2.canStartOnboarding(flowId: 'first-run', version: 'v2'),
        isTrue,
      );
    });

    test('markFeatureSeen hides the badge flag', () async {
      final c = GuidanceController(storage: MemoryGuidanceStorage());
      await c.init();
      expect(c.isFeatureSeen('inbox-flow-b'), isFalse);
      await c.markFeatureSeen('inbox-flow-b');
      expect(c.isFeatureSeen('inbox-flow-b'), isTrue);
    });
  });

  group('GuidanceController (tour over real overlay)', () {
    testWidgets('sequential steps 1→2→Finish with Skip/Done', (tester) async {
      final storage = MemoryGuidanceStorage();
      final c = GuidanceController(storage: storage);
      await c.init();

      final k1 = GlobalKey();
      final k2 = GlobalKey();
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) {
            ctx = context;
            return Scaffold(
              body: Column(
                children: [
                  KeyedSubtree(key: k1, child: const SizedBox(width: 80, height: 60)),
                  KeyedSubtree(key: k2, child: const SizedBox(width: 80, height: 60)),
                ],
              ),
            );
          },
        ),
      ));

      final started = c.beginOnboardingIfUnseen(
        ctx,
        flowId: 'first-run',
        version: 'v1',
        steps: [
          GuidanceStep(id: 's1', targetKey: k1, title: 'Step one', body: 'First body'),
          GuidanceStep(id: 's2', targetKey: k2, title: 'Step two', body: 'Second body'),
        ],
      );
      expect(started, isTrue);
      expect(c.isActive, isTrue);

      await tester.pumpAndSettle();
      // Step 1 visible with Skip + Next.
      expect(find.text('Step one'), findsOneWidget);
      expect(find.text('1/2'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);

      // Advance → step 2 completed is persisted.
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Step two'), findsOneWidget);
      expect(find.text('2/2'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(
        storage.flags['step.onboarding:first-run:v1.s1'],
        isTrue,
        reason: 'completed step persisted',
      );

      // Finish → flow seen, overlay gone, no spam afterwards.
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(c.isActive, isFalse);
      expect(find.text('2/2'), findsNothing);
      expect(
        storage.flags['seen.onboarding:first-run:v1'],
        isTrue,
      );
      expect(
        c.beginOnboardingIfUnseen(ctx, flowId: 'first-run', version: 'v1', steps: const []),
        isFalse,
      );
    });

    testWidgets('Skip retires the tour and marks it seen', (tester) async {
      final c = GuidanceController(storage: MemoryGuidanceStorage());
      await c.init();
      final k1 = GlobalKey();
      final k2 = GlobalKey();
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) {
            ctx = context;
            return Scaffold(
              body: Column(
                children: [
                  KeyedSubtree(key: k1, child: const SizedBox(width: 80, height: 60)),
                  KeyedSubtree(key: k2, child: const SizedBox(width: 80, height: 60)),
                ],
              ),
            );
          },
        ),
      ));

      c.beginOnboardingIfUnseen(
        ctx,
        flowId: 'tour',
        version: 'v1',
        steps: [
          GuidanceStep(id: 'a', targetKey: k1, title: 'T', body: 'B'),
          GuidanceStep(id: 'b', targetKey: k2, title: 'T2', body: 'B2'),
        ],
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(c.isActive, isFalse);
      expect(c.canStartOnboarding(flowId: 'tour', version: 'v1'), isFalse);
    });
  });

  group('geometry', () {
    const screen = Size(400, 800);

    test('prefers below when there is room, falls back to top', () {
      // Target near the top → space below → bottom.
      final nearTop = Rect.fromLTWH(100, 100, 80, 60);
      expect(
        resolvePlacement(
            target: nearTop, tooltipSize: const Size(200, 100), screen: screen),
        TooltipPlacement.bottom,
      );
      // Target near the bottom → no room below → top.
      final nearBottom = Rect.fromLTWH(100, 700, 80, 60);
      expect(
        resolvePlacement(
            target: nearBottom, tooltipSize: const Size(200, 100), screen: screen),
        TooltipPlacement.top,
      );
    });

    test('explicit placement is respected (not overridden)', () {
      final r = Rect.fromLTWH(100, 100, 80, 60);
      expect(
        resolvePlacement(
            target: r,
            tooltipSize: const Size(200, 100),
            screen: screen,
            preferred: TooltipPlacement.left),
        TooltipPlacement.left,
      );
    });

    test('offset is clamped inside the screen', () {
      const screen = Size(400, 800);
      // Target hugging the left edge → tooltip would overflow left → clamped.
      final nearLeft = Rect.fromLTWH(0, 100, 80, 60);
      final o = tooltipOffset(
        target: nearLeft,
        tooltipSize: const Size(300, 100),
        screen: screen,
        placement: TooltipPlacement.bottom,
      );
      expect(o.dx, 12); // pinned to the margin, never negative
      expect(o.dx + 300, lessThanOrEqualTo(screen.width - 12));

      // Target near the right edge → clamped right too.
      final nearRight = Rect.fromLTWH(320, 100, 80, 60);
      final o2 = tooltipOffset(
        target: nearRight,
        tooltipSize: const Size(300, 100),
        screen: screen,
        placement: TooltipPlacement.bottom,
      );
      expect(o2.dx + 300, lessThanOrEqualTo(screen.width - 12));
    });
  });

  group('FeatureBadge', () {
    testWidgets('shows "New" until the feature is seen, then hides', (tester) async {
      final c = GuidanceController(storage: MemoryGuidanceStorage());
      await c.init();
      await tester.pumpWidget(
        ChangeNotifierProvider<GuidanceController>.value(
          value: c,
          child: const MaterialApp(
            home: Scaffold(
              body: FeatureBadge(
                config: FeatureBadgeConfig(featureKey: 'inbox-flow-b'),
                child: Icon(Icons.inbox_outlined),
              ),
            ),
          ),
        ),
      );
      expect(find.text('New'), findsOneWidget);

      await c.markFeatureSeen('inbox-flow-b');
      await tester.pump();
      expect(find.text('New'), findsNothing, reason: 'badge retired once seen');
    });
  });

  group('DisabledStateHelper', () {
    testWidgets('tap on disabled control explains reason + unlock hint',
        (tester) async {
      final c = GuidanceController(storage: MemoryGuidanceStorage());
      await c.init();
      await tester.pumpWidget(
        ChangeNotifierProvider<GuidanceController>.value(
          value: c,
          child: const MaterialApp(
            home: Scaffold(
              body: Center(
                child: DisabledStateHelper(
                  enabled: false,
                  config: DisabledStateConfig(
                    reason: 'The question is empty.',
                    unlockHint: 'Type a question to enable Ask.',
                  ),
                  child: IconButton.filled(
                    onPressed: null,
                    icon: Icon(Icons.arrow_upward),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pumpAndSettle();
      expect(find.text('The question is empty.'), findsOneWidget);
      expect(find.text('Type a question to enable Ask.'), findsOneWidget);
    });

    testWidgets('enabled control still fires its own action (no interception)',
        (tester) async {
      final c = GuidanceController(storage: MemoryGuidanceStorage());
      await c.init();
      var tapped = false;
      await tester.pumpWidget(
        ChangeNotifierProvider<GuidanceController>.value(
          value: c,
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: DisabledStateHelper(
                  enabled: true,
                  config: const DisabledStateConfig(reason: 'n/a'),
                  child: ElevatedButton(
                    onPressed: () => tapped = true,
                    child: const Text('Go'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue, reason: 'tap passed through to the button');
      expect(find.text('n/a'), findsNothing, reason: 'no explanation for enabled');
    });
  });
}
