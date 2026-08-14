# Tests

- **ADS-001** `AdCooldown`: initially ready; blocks a second show before the
  interval elapses; becomes ready again after the interval (injectable clock).
- **ADS-002** `AdCooldown` with zero/negative interval never blocks.
- **ADS-003** Config resolution: with `testAds=true` all unit types resolve to
  Google test IDs (Android + iOS); production IDs used when `testAds=false`.
- **ADS-004** (manual, device): UMP consent form appears for EEA test
  geography; banner loads only after consent; interstitial shows once per
  cooldown and never on app launch.
- **ADS-005** (manual, device): bottom ad banner fully visible with Android
  3-button navigation (edge-to-edge).
