import 'package:path/path.dart' as p;

import 'database.dart';
import 'wiki_index.dart';
import 'wiki_store.dart';

/// Open the SQLite index at `<root>/.agentwiki/index.sqlite` (io only).
WikiIndex openIndex(WikiStore store) =>
    IndexDb.open(p.join(store.root, '.agentwiki', 'index.sqlite'));
