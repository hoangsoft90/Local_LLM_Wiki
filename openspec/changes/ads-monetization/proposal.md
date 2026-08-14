# Change: AdMob Monetization (test mode, interstitial + cooldown, UMP consent)

## Problem

The app only shows a single AdMob **banner** (Home + Page). To earn from
ads on Play Store / App Store we need:

1. A **test-ads flag** so development builds never risk AdMob invalid-traffic
   penalties (the app currently loads production Android units even in debug).
2. **Interstitial** ads with a **cooldown** so revenue surfaces exist without
   spamming the user (AdMob policy: no app-launch ads, no back-to-back ads).
3. **UMP consent** (Google User Messaging Platform) so EEA/UK users get a
   consent form before any ad requests — required for App Store / Play review.
4. Bottom content (incl. ad banner) must never sit behind the Android
   3-button system navigation bar (targetSdk 36 → edge-to-edge enforced).

## Proposal

### 1. Config flag (REQ-1)

`lib/ads/ad_config.dart` gains a single `testAds` flag (default **true** for
this change). When true, **all** ad units (banner / interstitial / rewarded)
resolve to Google's official test IDs on both platforms — so dev/test builds
never touch real inventory.

### 2. Interstitial + cooldown (REQ-2)

- New `lib/ads/ad_cooldown.dart`: pure-Dart `AdCooldown` with an injectable
  clock — tracks the last show time and only allows a new interstitial after
  `minInterval` elapsed. Unit-testable on the VM.
- `AdService` (io) gains `loadInterstitial()` (preload once) and
  `showInterstitialIfAvailable()` — shows only when loaded **and** cooldown
  passed; returns false otherwise (caller treats as no-op).
- Trigger: switching tabs in `AppShell` (Home → other tab) attempts an
  interstitial, gated by cooldown + load state. Never at app launch.

### 3. UMP consent (REQ-3)

- New `lib/ads/consent_manager.dart` (conditional io/web). io uses
  `ConsentInformation.requestConsentInfoUpdate` →
  `ConsentForm.loadAndShowConsentFormIfRequired()` → gates
  `canRequestAds()`. Web is a no-op stub (no ads on web).
- `main.dart` starts consent (fire-and-forget, non-blocking splash).
- `AdService.ready` waits for consent resolution before allowing ad loads.

### 4. Bottom-system-nav safety (REQ-4)

- M3 `NavigationBar` already SafeArea's the bottom inset internally.
- `PageScreen` / `SearchScreen` (full-screen routes, no bottom nav) get a
  bottom `SafeArea` so their last item / the ad banner never sits behind the
  Android 3-button nav.
- `AdBanner` already wraps itself in `SafeArea(top: false)`.

## Non-goals

- No rewarded ads UI (IDs reserved; wiring later).
- No app-launch interstitial (AdMob policy).
- iOS production ad units still pending (no iOS AdMob app yet) — test IDs used
  there until created.
