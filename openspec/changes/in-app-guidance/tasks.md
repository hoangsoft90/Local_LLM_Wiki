# Tasks — In-app Guidance & Onboarding

- [ ] `shared_preferences` dependency.
- [ ] `guidance_models.dart` — `TooltipPlacement`, `GuidanceStep`, `FeatureBadgeConfig`, `DisabledStateConfig`.
- [ ] `guidance_storage.dart` — `GuidanceStorage` + `PrefsGuidanceStorage` + `MemoryGuidanceStorage`.
- [ ] `guidance_state.dart` — `GuidanceController` (once-only flows, version key, sequential steps, seen/stepCompleted persistence).
- [ ] `guidance_geometry.dart` — `globalRectOf`, `resolvePlacement`, `tooltipOffset`, `TooltipCard` (shared popup visual).
- [ ] `spotlight_overlay.dart` — dim + rounded cutout + animated auto-positioned tooltip + Skip/Next/Done + step indicator.
- [ ] `feature_badge.dart`, `disabled_state_helper.dart`.
- [ ] Integration: `app.dart` (MultiProvider + GuidanceController), `app_shell.dart` (first-run trigger + Inbox badge seen), `home_screen.dart` (target GlobalKeys), `ask_screen.dart` (DisabledStateHelper on send).
- [ ] `test/guidance_test.dart` — controller logic, geometry, widget tests (FeatureBadge, DisabledStateHelper).
- [ ] Verify: `flutter analyze`, `flutter test`, `flutter build web`.
