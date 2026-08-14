import 'dart:async';

import 'package:flutter/material.dart';

import 'ads/ad_service.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Khởi động AdMob init + UMP consent flow (fire-and-forget — không chặn
  // splash/UI). AdBanner/interstitial tự gate trên consent trước khi load.
  unawaited(AdService.instance.ready.then((_) {}, onError: (_) {}));
  runApp(const AgentWikiApp());
}
