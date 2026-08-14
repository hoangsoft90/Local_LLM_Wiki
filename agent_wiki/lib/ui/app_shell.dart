import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'guidance/guidance_models.dart';
import 'guidance/guidance_state.dart';
import 'state/app_state.dart';
import 'ask_screen.dart';
import 'home_screen.dart';
import 'inbox_screen.dart';
import 'settings_screen.dart';
import 'sources_screen.dart';

/// Persisted key for the "New" badge on the Inbox (Flow B / corroboration).
const kInboxFeatureKey = 'inbox-flow-b';

/// First-run onboarding: highlight the compounding-loop quick actions.
final List<GuidanceStep> _firstRunSteps = [
  GuidanceStep(
    id: 'ask',
    targetKey: onboardingAskKey,
    title: 'Ask your wiki',
    body: 'Ask questions and get answers with citations — the wiki only '
        'answers from knowledge it already has.',
  ),
  GuidanceStep(
    id: 'import',
    targetKey: onboardingImportKey,
    title: 'Import sources',
    body: 'Bring in a markdown file and it is compiled into evidence-backed '
        'pages automatically.',
  ),
  GuidanceStep(
    id: 'inbox',
    targetKey: onboardingInboxKey,
    title: 'Review in Inbox',
    body: 'New drafts and status upgrades land here for your review — accept '
        'or reject with cross-model corroboration.',
  ),
];

/// Bottom-navigation shell for the mobile app (mobile-ui REQ-1).
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell> {
  int _tab = 0;
  bool _waitingForGuidanceReady = false;

  @override
  void initState() {
    super.initState();
    // Start the first-run tour once the Home quick actions are laid out and
    // the guidance state (persisted flags) is loaded.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _maybeStartOnboarding());
  }

  void _maybeStartOnboarding() {
    final guidance = context.read<GuidanceController>();
    if (!guidance.ready) {
      if (_waitingForGuidanceReady) return;
      _waitingForGuidanceReady = true;
      guidance.addListener(_onGuidanceReady);
      return;
    }
    _tryStartTour(guidance);
  }

  void _onGuidanceReady() {
    if (!mounted) return;
    final guidance = context.read<GuidanceController>();
    guidance.removeListener(_onGuidanceReady);
    _waitingForGuidanceReady = false;
    _tryStartTour(guidance);
  }

  void _tryStartTour(GuidanceController guidance) {
    final started = guidance.beginOnboardingIfUnseen(
      context,
      flowId: 'first-run',
      version: 'v1',
      steps: _firstRunSteps,
    );
    if (started) {
      // When the tour ends (Skip or Done), retire the "New" badge too.
      guidance.addListener(_onTourEnded);
    }
  }

  void _onTourEnded() {
    if (!mounted) return;
    final guidance = context.read<GuidanceController>();
    if (guidance.isActive) return;
    guidance.removeListener(_onTourEnded);
    guidance.markFeatureSeen(kInboxFeatureKey);
  }

  void switchTab(int tab) => setState(() => _tab = tab);

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final pending = app.pendingInboxCount;

    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [
          HomeScreen(),
          AskScreen(),
          InboxScreen(),
          SourcesScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          setState(() => _tab = i);
          if (i == 2) {
            // Opening Inbox retires the "New" badge.
            context.read<GuidanceController>().markFeatureSeen(kInboxFeatureKey);
          }
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Ask',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: pending > 0,
              label: Text('$pending'),
              child: const Icon(Icons.inbox_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: pending > 0,
              label: Text('$pending'),
              child: const Icon(Icons.inbox),
            ),
            label: 'Inbox',
          ),
          const NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description),
            label: 'Sources',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
