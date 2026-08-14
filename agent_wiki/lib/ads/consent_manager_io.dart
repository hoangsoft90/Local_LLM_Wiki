import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Consent gate backed by Google UMP (User Messaging Platform) — io platform.
///
/// Flow (AdMob docs): request a consent-info update → if a consent form is
/// required (EEA/UK + UK/CH…) load & show it → afterwards
/// [canRequestAds] tells whether ad requests are allowed.
///
/// Deliberately **non-blocking & non-throwing**: the app must never wait on
/// consent before showing its UI; ads simply won't load until consent is
/// resolved. On consent-gathering errors we fail CLOSED (no ads) rather than
/// request ads without consent (policy-safe).
abstract class ConsentManager {
  /// Start the consent flow (idempotent, fire-and-forget safe).
  Future<void> initialize();

  /// True once ads may be requested (consent obtained or not required).
  Future<bool> canRequestAds();
}

class UmConsentManager implements ConsentManager {
  Future<void>? _init;

  @override
  Future<void> initialize() => _init ??= _run();

  Future<void> _run() async {
    try {
      // Explicitly tag "not underage" so we never serve personalized ads to
      // children without the required safeguards.
      await _requestInfoUpdate(
          ConsentRequestParameters(tagForUnderAgeOfConsent: false));
      // Shows the form when required; returns immediately otherwise.
      await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
      debugPrint('[UMP] consent flow finished');
    } catch (e) {
      // Never take the app down over consent. AdBanner/interstitial gate on
      // canRequestAds() which returns false on error → no ads, no crash.
      debugPrint('[UMP] consent flow failed: $e');
    }
  }

  /// The plugin's `requestConsentInfoUpdate` is callback-based — adapt to a
  /// Future so callers can await it cleanly.
  Future<void> _requestInfoUpdate(ConsentRequestParameters params) {
    final completer = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () => completer.complete(),
      (FormError error) => completer.completeError(error),
    );
    return completer.future;
  }

  @override
  Future<bool> canRequestAds() async {
    await initialize();
    try {
      return await ConsentInformation.instance.canRequestAds();
    } catch (e) {
      debugPrint('[UMP] canRequestAds failed: $e');
      return false; // fail closed — no ads without consent
    }
  }
}
