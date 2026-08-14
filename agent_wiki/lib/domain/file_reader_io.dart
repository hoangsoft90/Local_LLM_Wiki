import 'dart:io';

/// Read an arbitrary file path (mobile/desktop only — web has no dart:io).
String readFileString(String path) => File(path).readAsStringSync();
