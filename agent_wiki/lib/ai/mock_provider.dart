import 'llm_provider.dart';

/// Deterministic LLM for tests (openspec: ai-provider Behavior).
class MockLlmProvider implements LlmProvider {
  final Map<String, dynamic> Function(String system, String user)?
      onStructured;
  final String Function(String system, String user)? onGenerate;

  int structuredCalls = 0;
  int generateCalls = 0;
  final List<String> userPrompts = [];
  final List<String> systemPrompts = [];

  MockLlmProvider({this.onStructured, this.onGenerate});

  @override
  String get name => 'mock';

  @override
  Future<String> generate({
    required String system,
    required String user,
    String? model,
  }) async {
    generateCalls++;
    systemPrompts.add(system);
    userPrompts.add(user);
    if (onGenerate != null) return onGenerate!(system, user);
    throw LlmException('MockLlmProvider: no onGenerate behavior set');
  }

  @override
  Future<Map<String, dynamic>> structured({
    required String system,
    required String user,
    String? model,
  }) async {
    structuredCalls++;
    systemPrompts.add(system);
    userPrompts.add(user);
    if (onStructured != null) return onStructured!(system, user);
    throw LlmException('MockLlmProvider: no onStructured behavior set');
  }
}

/// Heuristic, offline provider so the app can be dogfooded without an API
/// key. Reads prompt markers to produce deterministic, source-grounded output.
class DemoLlmProvider implements LlmProvider {
  @override
  String get name => 'demo';

  @override
  Future<String> generate({
    required String system,
    required String user,
    String? model,
  }) async =>
      'Demo answer (no API key configured). Add a key in Settings for AI '
      'answers.';

  @override
  Future<Map<String, dynamic>> structured({
    required String system,
    required String user,
    String? model,
  }) async {
    final type = RegExp(r'PROMPT_TYPE: (\w+)').firstMatch(system)?.group(1);
    switch (type) {
      case 'compile':
        return _demoCompile(user);
      case 'ask':
        return _demoAsk(user);
      case 'draft_patch':
        return _demoDraft();
      case 'corroborate':
        return {'corroborated': true, 'notes': 'Demo mode: auto-corroborated.'};
      default:
        throw LlmException('DemoLlmProvider: unknown prompt type');
    }
  }

  Map<String, dynamic> _demoCompile(String user) {
    final source = _afterMarker(user, 'UNTRUSTED SOURCE:');
    final sentences = RegExp(r'[^.!?\n]+[.!?]')
        .allMatches(source)
        .map((m) => m.group(0)!.trim())
        .where((s) => s.isNotEmpty)
        .take(4)
        .toList();
    final title = _titleFrom(source);
    final claims = sentences.map((s) {
      return {
        'statement': s,
        'hypothesis': false,
        'evidence': [
          {'location': 'Source text', 'quote': s},
        ],
      };
    }).toList();
    return {
      'pages': [
        {
          'title': title,
          'page_type': 'concept',
          'claims': claims,
        },
      ],
    };
  }

  Map<String, dynamic> _demoAsk(String user) {
    final knowledge = _afterMarker(user, 'KNOWLEDGE:');
    final question = _afterMarker(user, 'Question:').trim();
    final firstPage = RegExp(r'\[([^\]]+)\]').firstMatch(knowledge)?.group(1);
    final firstPageId =
        RegExp(r'page_id: (\S+)').firstMatch(knowledge)?.group(1);
    final sentences = RegExp(r'[^.!?\n]+[.!?]')
        .allMatches(knowledge)
        .map((m) => m.group(0)!.trim())
        .where((s) => s.isNotEmpty)
        .take(3)
        .toList();
    if (sentences.isEmpty) {
      return {
        'answer': 'The wiki has no knowledge about this yet.',
        'citations': <Map<String, dynamic>>[],
      };
    }
    return {
      'answer': 'Based on the wiki knowledge${firstPage != null ? ' ($firstPage)' : ''}:\n\n'
          '- ${sentences.join('\n- ')}\n\n(Demo mode — no API key configured. '
          'Question: $question)',
      'citations': firstPageId == null
          ? <Map<String, dynamic>>[]
          : [
              {'page_id': firstPageId},
            ],
    };
  }

  Map<String, dynamic> _demoDraft() => {'ops': <Map<String, dynamic>>[]};

  String _titleFrom(String source) {
    final first = RegExp(r'[^.!?\n]+[.!?]').firstMatch(source)?.group(0);
    if (first == null) return 'Untitled source';
    return truncateSlug(first);
  }

  String truncateSlug(String s) {
    final clean = s.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
    return clean.length > 60 ? clean.substring(0, 60) : clean;
  }
}

String _afterMarker(String text, String marker) {
  final idx = text.indexOf(marker);
  if (idx < 0) return '';
  return text.substring(idx + marker.length);
}
