import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../ai/llm_provider.dart';
import '../ai/mock_provider.dart';
import '../ai/openrouter_provider.dart';
import '../data/wiki_repository.dart';

/// Key-value store abstraction so tests can avoid platform channels.
abstract class KeyStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Platform secure storage (Keychain / Keystore).
class SecureKeyStore implements KeyStore {
  final _storage = const FlutterSecureStorage();

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {}
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (_) {}
  }
}

/// Fallback key store backed by the wiki's settings.json (offline-safe).
class FileKeyStore implements KeyStore {
  final WikiRepository repo;
  FileKeyStore(this.repo);

  static const prefix = 'key_';

  @override
  Future<String?> read(String key) async =>
      repo.settings['$prefix$key'] as String?;

  @override
  Future<void> write(String key, String value) async {
    final s = Map<String, dynamic>.from(repo.settings);
    s['$prefix$key'] = value;
    repo.saveSettings(s);
  }

  @override
  Future<void> delete(String key) async {
    final s = Map<String, dynamic>.from(repo.settings);
    s.remove('$prefix$key');
    repo.saveSettings(s);
  }
}

/// App settings: API key (secure), primary + corroboration models.
class SettingsService {
  final WikiRepository repo;
  final KeyStore keys;

  static const apiKeyName = 'openrouter_api_key';
  static const defaultPrimary = 'anthropic/claude-sonnet-4';
  static const defaultCorroboration = 'openai/gpt-4o-mini';

  SettingsService(this.repo, {KeyStore? keys})
      : keys = keys ?? SecureKeyStore();

  Future<String?> apiKey() => keys.read(apiKeyName);

  Future<void> setApiKey(String? value) async {
    if (value == null || value.trim().isEmpty) {
      await keys.delete(apiKeyName);
    } else {
      await keys.write(apiKeyName, value.trim());
    }
  }

  Future<String> primaryModel() async {
    final m = repo.meta.primaryModel;
    return (m == null || m.isEmpty) ? defaultPrimary : m;
  }

  Future<String> corroborationModel() async {
    final m = repo.meta.corroborationModel;
    return (m == null || m.isEmpty) ? defaultCorroboration : m;
  }

  Future<void> setPrimaryModel(String model) async {
    repo.updateMeta(repo.meta.copyWith(primaryModel: model));
  }

  Future<void> setCorroborationModel(String model) async {
    repo.updateMeta(repo.meta.copyWith(corroborationModel: model));
  }

  /// Resolve the LLM provider for the given API key (or null → demo mode).
  static LlmProvider providerFor(String? apiKey) =>
      apiKey == null || apiKey.isEmpty
          ? DemoLlmProvider()
          : OpenRouterProvider(apiKey: apiKey);
}
