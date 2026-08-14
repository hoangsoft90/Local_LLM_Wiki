/// Path-based file-system abstraction so the canonical store runs on both
/// `dart:io` (mobile/desktop) and localStorage (web) with identical semantics.
///
/// All methods are synchronous — matching the existing `WikiStore` usage.
/// Paths are platform strings (OS paths on io, `<root>/rel/path` on web).
abstract class FileSystem {
  /// True when [path] exists as a file or a directory.
  bool exists(String path);

  /// Create a directory (recursively). No-op if it already exists.
  /// On localStorage directories are virtual, so this is a no-op.
  void createDir(String path);

  /// Full paths of the files under [path]. Non-recursive returns only
  /// immediate children (a `history/` subdir is not expanded). Returns []
  /// when the directory does not exist.
  List<String> listFiles(String path, {bool recursive = false});

  /// Read a file's content. Throws if the file does not exist.
  String readAsString(String path);

  /// Write a file, overwriting any existing content.
  void writeAsString(String path, String content);

  /// Delete a single file (no-op if missing).
  void delete(String path);

  /// Delete a directory and everything under it (or a single file).
  void deleteRecursive(String path);
}
