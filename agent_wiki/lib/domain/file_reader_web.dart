/// Web has no arbitrary filesystem access — import via picked-file bytes
/// (`PlatformFile.bytes` from file_picker) instead.
String readFileString(String path) =>
    throw UnsupportedError('Cannot read arbitrary paths on web; use bytes.');
