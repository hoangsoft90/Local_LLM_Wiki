import 'index_io.dart' if (dart.library.html) 'index_web.dart' as impl;
import 'wiki_index.dart';
import 'wiki_store.dart';

/// Platform-appropriate derived index: SQLite on mobile/desktop,
/// in-memory-over-localStorage on web.
WikiIndex openIndex(WikiStore store) => impl.openIndex(store);
