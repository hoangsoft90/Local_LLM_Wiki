/// Web stub — `google_mobile_ads` has no web implementation, so no consent is
/// needed and ads are never requested. Keeps the io surface.
abstract class ConsentManager {
  Future<void> initialize();

  Future<bool> canRequestAds();
}

class UmConsentManager implements ConsentManager {
  @override
  Future<void> initialize() async {}

  @override
  Future<bool> canRequestAds() async => true;
}
