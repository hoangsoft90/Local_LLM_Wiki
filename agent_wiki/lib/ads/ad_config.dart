/// AdMob configuration — single place to switch test → production ad units.
///
/// **Flag `testAds`**: khi `true` (mặc định cho dev), MỌI loại ad unit
/// (banner / interstitial / rewarded) dùng test ID chính thức của Google trên
/// cả 2 platform → không bao giờ chạm inventory thật lúc dev/test, tránh
/// invalid-traffic penalty từ AdMob. Đổi sang `false` khi release:
///
/// 1. Android: đã có App ID + banner/interstitial/rewarded production (xem dưới).
/// 2. iOS: chưa có app/ad unit riêng trên AdMob → luôn test tới khi tạo được
///    (ad unit ID là per-platform, KHÔNG dùng chung Android/iOS được).
///
/// ⚠️ App ID trong `AndroidManifest.xml` là ID thật; `Info.plist` (iOS) giữ
/// test ID chờ tạo app iOS trên AdMob console.
library;

/// `true` = test ads (dev an toàn) / `false` = production ads.
const bool testAds = true;

/// Khoảng tối thiểu giữa 2 lần hiển thị interstitial (chống spam, đúng
/// AdMob policy: không hiện ad liên tiếp / lúc khởi động app).
const Duration interstitialMinInterval = Duration(minutes: 2);

// ---------- Test IDs chính thức của Google (dev — không bị phạt) ----------

const String _kAndroidTestBanner = 'ca-app-pub-3940256099942544/6300978111';
const String _kIosTestBanner = 'ca-app-pub-3940256099942544/2934735716';
const String _kAndroidTestInterstitial =
    'ca-app-pub-3940256099942544/1033173712';
const String _kIosTestInterstitial = 'ca-app-pub-3940256099942544/4411468910';
const String _kAndroidTestRewarded = 'ca-app-pub-3940256099942544/5224354917';
const String _kIosTestRewarded = 'ca-app-pub-3940256099942544/1712485313';

// ---------- Production (Android — đã tạo trên AdMob) ----------

/// Banner thật (Android) — ca-app-pub-6917313063209470/1911246375.
const String _kAndroidProdBanner = 'ca-app-pub-6917313063209470/1911246375';

/// Interstitial thật (Android) — ca-app-pub-6917313063209470/1759771350.
const String kAndroidProdInterstitial =
    'ca-app-pub-6917313063209470/1759771350';

/// Rewarded thật (Android) — ca-app-pub-6917313063209470/9446689683.
const String kAndroidProdRewarded = 'ca-app-pub-6917313063209470/9446689683';

/// Trả về banner ad unit ID cho platform hiện tại.
/// Android: test hoặc production theo [testAds].
/// iOS: chưa có production ad unit → luôn test tới khi tạo được.
String bannerAdUnitId({required bool isAndroid}) {
  if (isAndroid) {
    return testAds ? _kAndroidTestBanner : _kAndroidProdBanner;
  }
  return _kIosTestBanner;
}

/// Trả về interstitial ad unit ID cho platform hiện tại.
String interstitialAdUnitId({required bool isAndroid}) {
  if (isAndroid) {
    return testAds ? _kAndroidTestInterstitial : kAndroidProdInterstitial;
  }
  return _kIosTestInterstitial;
}

/// Trả về rewarded ad unit ID cho platform hiện tại (chưa có UI dùng).
String rewardedAdUnitId({required bool isAndroid}) {
  if (isAndroid) {
    return testAds ? _kAndroidTestRewarded : kAndroidProdRewarded;
  }
  return _kIosTestRewarded;
}
