import 'dart:collection';

import 'package:web/web.dart' as web;

import 'fs_interface.dart';
import 'local_storage_fs.dart';

/// Bridge package:web's `Storage` (JS interop, not a Dart Map) to
/// `Map<String, String>` so `LocalStorageFileSystem` can use it.
class _StorageMap extends MapMixin<String, String> {
  _StorageMap(this._storage);

  final web.Storage _storage;

  @override
  String? operator [](Object? key) => _storage.getItem('$key');

  @override
  void operator []=(String key, String value) =>
      _storage.setItem(key, value);

  @override
  Iterable<String> get keys sync* {
    for (var i = 0; i < _storage.length; i++) {
      final k = _storage.key(i);
      if (k != null) yield k;
    }
  }

  @override
  String? remove(Object? key) {
    final v = _storage.getItem('$key');
    _storage.removeItem('$key');
    return v;
  }

  @override
  void clear() => _storage.clear();
}

/// Factory for the web platform (selected by conditional import).
FileSystem createFileSystem() =>
    LocalStorageFileSystem(_StorageMap(web.window.localStorage));
