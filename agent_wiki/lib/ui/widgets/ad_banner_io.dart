import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../ads/ad_service.dart';

/// Banner AdMob hiển thị ở cuối màn hình đọc (Home, Page) — io implementation.
///
/// - Await `AdService.ready` (MobileAds init) trước khi load — tránh load
///   sớm làm fail vĩnh viễn.
/// - Retry 1 lần nếu load fail tạm thời (cold start / network).
/// - Khi không có ad hoặc ads không khả dụng → `SizedBox.shrink()`
///   (không chiếm chỗ, không vỡ layout).
/// - Tự dispose ad khi widget bị xoá khỏi cây.
///
/// ⚠️ KHÔNG đặt trên màn hình hiển thị nội dung AI-generated (Ask screen) —
///     AdMob policy hạn chế ads trên "replicated/low-value content".
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  static const _maxAttempts = 2;

  BannerAd? _banner;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final unitId = AdService.instance.bannerAdUnitId;
    if (unitId == null) return; // nền tảng không hỗ trợ → không render gì

    // UMP consent gate: không request ad trước khi có consent (policy-safe).
    if (!await AdService.instance.adsAllowed) return;
    try {
      await AdService.instance.ready;
    } catch (_) {
      return; // AdMob không khả dụng → không render gì
    }
    if (!mounted) return;
    _loadBanner(unitId, attempt: 1);
  }

  void _loadBanner(String unitId, {required int attempt}) {
    final banner = BannerAd(
      adUnitId: unitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('[AdBanner] loaded ($unitId)');
          if (!mounted) return;
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('[AdBanner] FAILED ($unitId): ${error.code} '
              '${error.message}');
          ad.dispose();
          if (!mounted) return;
          setState(() => _banner = null);
          if (attempt < _maxAttempts) {
            // Retry 1 lần sau 2s cho lỗi tạm thời (cold start, network).
            Timer(const Duration(seconds: 2), () {
              if (mounted) _loadBanner(unitId, attempt: attempt + 1);
            });
          }
        },
      ),
    );
    _banner = banner;
    banner.load();
  }

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banner = _banner;
    if (!_loaded || banner == null) return const SizedBox.shrink();
    debugPrint('[AdBanner] build — rendering AdWidget');
    return Center(
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: AdWidget(ad: banner),
        ),
      ),
    );
  }
}
