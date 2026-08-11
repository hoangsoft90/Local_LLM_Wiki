import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart' as ad_config;

/// Singleton quản lý AdMob lifecycle cho toàn app.
///
/// - [ready] resolve sau khi `MobileAds.instance.initialize()` hoàn tất —
///   mọi nơi load ads PHẢI await nó trước (docs yêu cầu init trước khi load).
/// - [bannerAdUnitId] trả ID banner phù hợp platform (Android/iOS, test/prod).
/// - Idempotent: gọi [ready] nhiều lần an toàn; nếu init fail sẽ thử lại ở
///   lần access kế tiếp (không chặn app, banner chỉ không hiển thị).
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  Future<void>? _initFuture;

  /// Hoàn tất khi AdMob init xong. Throw nếu init fail.
  Future<void> get ready => _initFuture ??= _doInit();

  Future<void> _doInit() async {
    try {
      await MobileAds.instance.initialize();
      debugPrint('[AdService] initialized');
    } catch (e) {
      _initFuture = null; // cho phép thử lại ở lần access sau
      debugPrint('[AdService] init failed: $e');
      rethrow;
    }
  }

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
}
