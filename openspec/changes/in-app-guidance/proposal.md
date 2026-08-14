# Change: In-app Guidance & User Onboarding

## Motivation

New users land on an empty Home screen with no idea how the compounding loop
works (Ask → Import → Inbox), and new features ship without any in-product
announcement. Add a reusable in-app guidance system: first-run spotlight tour,
"New" feature badges, and disabled-state explanations.

## Design

Reusable module `agent_wiki/lib/ui/guidance/`, Flutter + provider + shared_preferences:

- **Components**
  - `FeatureBadge` — dot/label "New" overlay on an icon/button; hides once the
    feature key is marked seen.
  - `SpotlightOverlay` — dims the background, cuts a rounded highlight around
    the target (`GlobalKey`), shows an attached guide popup with Skip/Next/Done;
    tooltip auto-positions (prefers below, falls back top/left/right, clamps to
    screen) and animates between steps.
  - `DisabledStateHelper` — wraps a disabled control; tapping it shows a short
    tooltip explaining why it is disabled + the unlock condition.
- **Logic & state**
  - `GuidanceStorage` interface: `PrefsGuidanceStorage` (shared_preferences) +
    `MemoryGuidanceStorage` (tests).
  - `GuidanceController` (ChangeNotifier, provided at app root): persists
    `seen` flags (`seen.<key>`) and `stepCompleted` (`step.<key>`); shows each
    onboarding flow **once** (`onboarding:<flow>:<version>` — version bump
    re-shows); sequential steps (Step 1 → Step 2 → Finish) with Skip/Done.
  - No-spam: once a flow/feature is seen it never re-triggers in the same
    session or later sessions.
- **Integration (AgentWiki)**
  - First-run onboarding on Home: 3 steps highlighting Ask → Import → Inbox.
  - `FeatureBadge` "New" on the Inbox quick action (Flow B feature); marked seen
    when onboarding finishes or the Inbox tab is opened.
  - `DisabledStateHelper` on the Ask send button (disabled when the question is
    empty — explains "type a question first").

## Impact

- New: `lib/ui/guidance/*`, `test/guidance_test.dart`, OpenSpec change.
- Modified: `pubspec.yaml` (+`shared_preferences`), `app.dart` (provider),
  `ui/app_shell.dart`, `ui/home_screen.dart`, `ui/ask_screen.dart`.
- No change to canonical storage, patch ops, or AI logic.

## Acceptance

- `flutter analyze` clean; `flutter test` (existing 34 + new guidance tests) pass.
- Unit tests: once-only trigger + version bump re-show + step persistence;
  geometry (placement resolution + clamping); `FeatureBadge` show/hide;
  `DisabledStateHelper` tap-on-disabled explanation.
- `flutter build web` still compiles (module is platform-agnostic).
