/// AdMob configuration — single place to switch test → production ad units.
///
/// **Android**: đã sang production — App ID thật trong `AndroidManifest.xml`
/// (`ca-app-pub-6917313063209470~4401678345`) + banner thật bên dưới.
/// **iOS**: chưa có app/ad unit riêng trên AdMob → vẫn dùng test ID tới khi
/// tạo được (ad unit ID là per-platform, KHÔNG dùng chung Android/iOS được).
///
/// ⚠️ App ID trong `AndroidManifest.xml` đã là ID thật; `Info.plist` (iOS)
/// đang giữ test ID chờ tạo app iOS trên AdMob console.
library;

/// Android: `false` = production banner. iOS luôn dùng test ID (xem dưới).
const bool useTestAds = false;

/// Banner ad unit IDs (theo platform).
/// Test IDs chính thức của Google — dùng cho dev không bị phạt invalid traffic.
const String _kAndroidTestBanner = 'ca-app-pub-3940256099942544/6300978111';
const String _kIosTestBanner = 'ca-app-pub-3940256099942544/2934735716';

// ---------- Production (Android) ----------

/// Banner thật (Android) — ca-app-pub-6917313063209470/1911246375.
const String _kAndroidProdBanner = 'ca-app-pub-6917313063209470/1911246375';

// ---------- Reserved — chưa có UI/code dùng (lưu ID để dành) ----------

/// Interstitial thật (Android) — ca-app-pub-6917313063209470/1759771350.
/// Chưa có code dùng — thêm khi implement interstitial.
const String kAndroidProdInterstitial =
    'ca-app-pub-6917313063209470/1759771350';

/// Rewarded thật (Android) — ca-app-pub-6917313063209470/9446689683.
/// Chưa có code dùng — thêm khi implement rewarded.
const String kAndroidProdRewarded = 'ca-app-pub-6917313063209470/9446689683';

/// Trả về banner ad unit ID cho platform hiện tại.
/// Android: test hoặc production theo [useTestAds].
/// iOS: chưa có production ad unit → luôn test tới khi tạo được.
String bannerAdUnitId({required bool isAndroid}) {
  if (isAndroid) {
    return useTestAds ? _kAndroidTestBanner : _kAndroidProdBanner;
  }
  return _kIosTestBanner;
}
