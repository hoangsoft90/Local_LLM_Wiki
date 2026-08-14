import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../ads/ad_service.dart';
import '../../ai/llm_provider.dart';
import '../../core/models/models.dart';
import '../../data/wiki_repository.dart';
import '../../domain/ask_service.dart';
import '../../domain/compile_service.dart';
import '../../domain/import_service.dart';
import '../../domain/promote_service.dart';
import '../../domain/settings_service.dart';

/// App-wide state: repository + services, shared with the UI via provider.
class AppState extends ChangeNotifier {
  late WikiRepository repo;
  late SettingsService settings;
  late LlmProvider llm;
  late ImportService importer;
  late CompileService compiler;
  late AskService asker;
  late PromoteService promoter;

  bool initialized = false;
  String? error;
  bool _initStarted = false;

  Future<void> init({String? rootDir}) async {
    if (_initStarted) return;
    _initStarted = true;
    try {
      repo = await WikiRepository.open(rootDir: rootDir);
      settings = SettingsService(repo);
      _wireServices(await settings.apiKey());
      // AdMob init — fire-and-forget, không chặn màn hình splash.
      // Nếu init fail, AdBanner tự xử lý (không hiển thị) — không ảnh hưởng app.
      unawaited(AdService.instance.ready.then((_) {
        // Preload interstitial ngay khi SDK sẵn sàng (consent gate bên trong),
        // để sẵn khi user đổi tab.
        AdService.instance.loadInterstitial();
      }, onError: (_) {}));
      initialized = true;
      notifyListeners();
    } catch (e) {
      error = '$e';
      _initStarted = false; // cho phép thử lại
      notifyListeners();
    }
  }

  /// Thử khởi tạo lại sau lỗi (từ màn hình lỗi).
  Future<void> retryInit() async {
    error = null;
    notifyListeners();
    await init();
  }

  void _wireServices(String? apiKey) {
    llm = SettingsService.providerFor(apiKey);
    importer = ImportService(repo);
    compiler = CompileService(repo, llm, settings);
    asker = AskService(repo, llm, settings);
    promoter = PromoteService(repo, llm, settings);
  }

  /// Call after changing the API key / models in Settings.
  Future<void> reloadServices() async {
    _wireServices(await settings.apiKey());
    notifyListeners();
  }

  void refresh() => notifyListeners();

  // ---------- convenience getters ----------

  List<PageRecord> get pages => repo.listPages();
  int get pendingInboxCount => repo.pendingDraftCount();
  int get pageCount => repo.pageCount;
  int get claimCount => repo.claimCount;
  int get sourceCount => repo.sourceCount;
  int get revisionCount => repo.revisionCount;
  WikiMeta get meta => repo.meta;
  String get wikiRoot => repo.store.root;

  Future<String?> apiKey() => settings.apiKey();
}
