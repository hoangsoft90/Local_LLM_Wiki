import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart' as ad_config;
import 'ad_cooldown.dart';
import 'consent_manager.dart';

/// Singleton quản lý AdMob lifecycle cho toàn app (io: Android/iOS/desktop).
///
/// - [ready] resolve sau khi UMP consent flow + `MobileAds.instance.initialize()`
///   hoàn tất — mọi nơi load ads PHẢI await nó trước.
/// - [adsAllowed] = consent đã cho phép request ads (UMP). Ad không được load
///   trước khi consent sẵn sàng (policy-safe).
/// - [bannerAdUnitId] / [interstitialAdUnitId] theo platform (test/prod qua
///   `ad_config.testAds`).
/// - Interstitial: [loadInterstitial] preload 1 lần; [showInterstitialIfAvailable]
///   chỉ hiện khi đã load VÀ qua cooldown ([AdCooldown]) — chống spam.
/// - Idempotent: [ready] gọi nhiều lần an toàn; init fail sẽ thử lại ở lần
///   access kế tiếp (không chặn app, ad chỉ không hiển thị).
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  final ConsentManager _consent = UmConsentManager();
  final AdCooldown _interstitialCooldown =
      AdCooldown(minInterval: ad_config.interstitialMinInterval);

  Future<void>? _initFuture;
  InterstitialAd? _interstitial;

  /// Hoàn tất khi consent flow + AdMob init xong. Throw nếu init fail.
  Future<void> get ready => _initFuture ??= _doInit();

  Future<void> _doInit() async {
    // Consent trước (không bao giờ throw — xem consent_manager_io).
    await _consent.initialize();
    try {
      await MobileAds.instance.initialize();
      debugPrint('[AdService] initialized');
    } catch (e) {
      _initFuture = null; // cho phép thử lại ở lần access sau
      debugPrint('[AdService] init failed: $e');
      rethrow;
    }
  }

  /// True khi được phép request ads (consent obtained / not required).
  Future<bool> get adsAllowed => _consent.canRequestAds();

  /// Banner ad unit ID cho platform hiện tại.
  /// Trả null khi không hỗ trợ (không phải Android/iOS).
  String? get bannerAdUnitId {
    if (!kIsWeb && Platform.isAndroid) {
      return ad_config.bannerAdUnitId(isAndroid: true);
    }
    if (!kIsWeb && Platform.isIOS) {
      return ad_config.bannerAdUnitId(isAndroid: false);
    }
    return null;
  }

  /// Interstitial ad unit ID cho platform hiện tại (null khi không hỗ trợ).
  String? get interstitialAdUnitId {
    if (!kIsWeb && Platform.isAndroid) {
      return ad_config.interstitialAdUnitId(isAndroid: true);
    }
    if (!kIsWeb && Platform.isIOS) {
      return ad_config.interstitialAdUnitId(isAndroid: false);
    }
    return null;
  }

  // ---------- interstitial ----------

  /// Preload một interstitial (idempotent — chỉ load nếu chưa có).
  /// Không load khi chưa có consent.
  Future<void> loadInterstitial() async {
    final unitId = interstitialAdUnitId;
    if (unitId == null || _interstitial != null) return;
    if (!await adsAllowed) return;
    try {
      await ready;
    } catch (_) {
      return; // AdMob không khả dụng → không load gì
    }
    await InterstitialAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('[AdService] interstitial loaded');
          _interstitial = ad;
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('[AdService] interstitial FAILED: '
              '${error.code} ${error.message}');
          _interstitial = null;
        },
      ),
    );
  }

  /// Hiện interstitial đã preload nếu qua cooldown. Trả true khi hiện.
  /// No-op (false) khi chưa load hoặc còn trong cooldown.
  Future<bool> showInterstitialIfAvailable() async {
    final ad = _interstitial;
    if (ad == null) return false;
    if (!_interstitialCooldown.tryAcquire()) return false;
    _interstitial = null; // tiêu thụ — reload sau khi đóng
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (_) => unawaited(loadInterstitial()),
      onAdFailedToShowFullScreenContent: (failed, error) {
        debugPrint('[AdService] interstitial show failed: '
            '${error.code} ${error.message}');
        failed.dispose();
      },
    );
    await ad.show();
    return true;
  }
}
