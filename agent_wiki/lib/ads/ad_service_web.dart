/// Web stub — `google_mobile_ads` has no web implementation, so no ads are
/// shown on web. Keeps the same surface as the io [AdService].
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  Future<void> get ready async {}

  Future<bool> get adsAllowed async => true;

  String? get bannerAdUnitId => null;

  String? get interstitialAdUnitId => null;

  Future<void> loadInterstitial() async {}

  Future<bool> showInterstitialIfAvailable() async => false;
}
