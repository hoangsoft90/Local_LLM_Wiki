# Tasks

1. `ad_config.dart`: rename `useTestAds` → `testAds` (default `true`), add
   `interstitialAdUnitId()` / `rewardedAdUnitId()` (test/prod per platform),
   add `interstitialMinInterval` const.
2. `lib/ads/ad_cooldown.dart`: `AdCooldown` (injectable `now`, `tryAcquire()`).
3. `lib/ads/consent_manager.dart` + `_io.dart` + `_web.dart`: UMP consent flow.
4. `ad_service_io.dart`: consent-gated `ready`; `loadInterstitial()` +
   `showInterstitialIfAvailable()` (cooldown + loaded).
5. `ad_service_web.dart`: mirror the new surface as stubs.
6. `main.dart`: kick off consent init (fire-and-forget).
7. `app_shell.dart`: interstitial trigger on tab switch.
8. `page_screen.dart` / `search_screen.dart`: bottom `SafeArea` (3-button nav).
9. `ios/Runner/Info.plist`: `NSUserTrackingUsageDescription`.
10. Tests: `ad_cooldown_test.dart` (cooldown expiry, injectable clock),
    config unit resolution in test mode.
11. Docs + verify (analyze / test / build web) + commit + push (CI).
