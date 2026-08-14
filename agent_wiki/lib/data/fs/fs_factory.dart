import 'fs_interface.dart';
import 'fs_io.dart' if (dart.library.html) 'fs_web.dart' as impl;

/// Platform-appropriate filesystem: `dart:io` on mobile/desktop,
/// localStorage on web.
FileSystem createFileSystem() => impl.createFileSystem();
