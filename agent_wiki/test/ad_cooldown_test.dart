import 'package:agent_wiki/ads/ad_cooldown.dart';
import 'package:agent_wiki/ads/ad_config.dart' as ad_config;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdCooldown', () {
    test('ADS-001: ready initially, blocks inside the window, re-opens after',
        () {
      var now = DateTime(2026, 8, 14, 12, 0, 0);
      final cooldown = AdCooldown(
        minInterval: const Duration(minutes: 2),
        now: () => now,
      );

      expect(cooldown.isReady, isTrue, reason: 'never shown → ready');
      expect(cooldown.tryAcquire(), isTrue);
      expect(cooldown.tryAcquire(), isFalse,
          reason: 'second show inside the cooldown window is blocked');

      // 1 minute later — still inside the window.
      now = now.add(const Duration(minutes: 1));
      expect(cooldown.isReady, isFalse);

      // 1 more minute (2 total) — window elapsed → ready again.
      now = now.add(const Duration(minutes: 1));
      expect(cooldown.isReady, isTrue);
      expect(cooldown.tryAcquire(), isTrue);
    });

    test('ADS-002: zero/negative interval never blocks', () {
      final cooldown = AdCooldown(minInterval: Duration.zero);
      expect(cooldown.tryAcquire(), isTrue);
      expect(cooldown.isReady, isTrue,
          reason: 'zero interval → always ready');
      expect(cooldown.tryAcquire(), isTrue);
    });

    test('markShown records the last show time', () {
      final now = DateTime(2026, 8, 14, 9, 0, 0);
      final cooldown =
          AdCooldown(minInterval: const Duration(minutes: 5), now: () => now);
      cooldown.markShown();
      expect(cooldown.lastShown, now);
    });
  });

  group('ad_config test-mode resolution', () {
    test('ADS-003: testAds=true resolves every unit type to a Google test ID',
        () {
      expect(ad_config.testAds, isTrue,
          reason: 'dev/test must never touch real inventory');
      // Banner: both platforms use the official Google test IDs.
      expect(ad_config.bannerAdUnitId(isAndroid: true),
          'ca-app-pub-3940256099942544/6300978111');
      expect(ad_config.bannerAdUnitId(isAndroid: false),
          'ca-app-pub-3940256099942544/2934735716');
      // Interstitial: test IDs.
      expect(ad_config.interstitialAdUnitId(isAndroid: true),
          'ca-app-pub-3940256099942544/1033173712');
      expect(ad_config.interstitialAdUnitId(isAndroid: false),
          'ca-app-pub-3940256099942544/4411468910');
      // Rewarded: test IDs.
      expect(ad_config.rewardedAdUnitId(isAndroid: true),
          'ca-app-pub-3940256099942544/5224354917');
      expect(ad_config.rewardedAdUnitId(isAndroid: false),
          'ca-app-pub-3940256099942544/1712485313');
    });
  });
}
