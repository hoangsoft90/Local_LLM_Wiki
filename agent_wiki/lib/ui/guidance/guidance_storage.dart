import 'package:shared_preferences/shared_preferences.dart';

/// Persistence contract for guidance state (seen flags, completed steps).
///
/// Implementations are swappable so tests can use an in-memory store and the
/// app uses [PrefsGuidanceStorage] (SharedPreferences — works on
/// iOS/Android/web).
abstract class GuidanceStorage {
  /// All persisted keys that start with [prefix], with the prefix stripped.
  Future<Set<String>> loadKeys(String prefix);

  /// Persist a boolean flag (used for both seen flags and step completion).
  Future<void> setFlag(String key, bool value);
}

/// SharedPreferences-backed implementation (AsyncStorage/SharedPreferences
/// equivalent on Flutter). Keys are namespaced with a `guidance.` prefix to
/// avoid colliding with other app settings.
class PrefsGuidanceStorage implements GuidanceStorage {
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _instance async =>
      _prefs ??= await SharedPreferences.getInstance();

  static const _namespace = 'guidance.';

  @override
  Future<Set<String>> loadKeys(String prefix) async {
    final prefs = await _instance;
    final full = '$_namespace$prefix';
    return prefs
        .getKeys()
        .where((k) => k.startsWith(full))
        .map((k) => k.substring(full.length))
        .toSet();
  }

  @override
  Future<void> setFlag(String key, bool value) async {
    final prefs = await _instance;
    await prefs.setBool('$_namespace$key', value);
  }
}

/// In-memory implementation for tests.
class MemoryGuidanceStorage implements GuidanceStorage {
  final Map<String, bool> _flags = {};

  @override
  Future<Set<String>> loadKeys(String prefix) => Future.value(
      _flags.keys.where((k) => k.startsWith(prefix)).map((k) => k.substring(prefix.length)).toSet());

  @override
  Future<void> setFlag(String key, bool value) async => _flags[key] = value;

  /// Expose stored flags for assertions.
  Map<String, bool> get flags => Map.unmodifiable(_flags);
}
