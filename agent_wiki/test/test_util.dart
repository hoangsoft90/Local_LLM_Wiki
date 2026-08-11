import 'dart:io';

import 'package:agent_wiki/ai/mock_provider.dart';
import 'package:agent_wiki/data/wiki_repository.dart';

/// Open a wiki backed by a fresh temp directory.
Future<WikiRepository> tempRepo() async {
  final dir = Directory.systemTemp.createTempSync('agentwiki_test_');
  return WikiRepository.open(rootDir: dir.path);
}

/// Mock LLM that routes by prompt type.
MockLlmProvider routeMock({
  Map<String, dynamic> Function(String system, String user)? compile,
  Map<String, dynamic> Function(String system, String user)? ask,
  Map<String, dynamic> Function(String system, String user)? draft,
  Map<String, dynamic> Function(String system, String user)? corroborate,
}) {
  return MockLlmProvider(
    onStructured: (system, user) {
      final type = RegExp(r'PROMPT_TYPE: (\w+)').firstMatch(system)?.group(1);
      switch (type) {
        case 'compile':
          if (compile != null) return compile(system, user);
          break;
        case 'ask':
          if (ask != null) return ask(system, user);
          break;
        case 'draft_patch':
          if (draft != null) return draft(system, user);
          break;
        case 'corroborate':
          if (corroborate != null) return corroborate(system, user);
          break;
      }
      throw Exception('No mock behavior for $type');
    },
  );
}

/// Extract the `page_id:` value from an ask/draft user prompt's KNOWLEDGE
/// section (the knowledge context includes page ids).
String pageIdFromPrompt(String user) =>
    RegExp(r'page_id: (\S+)').firstMatch(user)?.group(1) ?? '';
