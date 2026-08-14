# Tests — In-app Guidance & Onboarding

> Unit + widget tests (VM, no browser needed).

- [ ] `GuidanceController` (Memory storage):
  - `beginOnboardingIfUnseen` starts once; second call (same session / after
    seen) does not re-show.
  - flow version bump → shows again (different key).
  - `next()` persists `stepCompleted` for each advanced step; `skip()`/`done`
    marks the flow seen.
  - `markFeatureSeen` makes `isFeatureSeen` true (badge hides).
- [ ] Geometry (`resolvePlacement`/`tooltipOffset`): prefers below when space
  allows, falls back top/left/right, clamps inside screen bounds.
- [ ] `FeatureBadge` widget: badge visible when unseen, absent when seen.
- [ ] `DisabledStateHelper` widget: tap while disabled shows reason + unlock
  condition; enabled child still fires its own action.
- [ ] Existing 34 tests still pass.
