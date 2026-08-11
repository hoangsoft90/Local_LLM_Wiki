/// LLM abstraction (openspec: ai-provider REQ-1).
///
/// `generate` returns raw text; `structured` returns a validated JSON map.
/// Implementations: OpenRouterProvider, MockLlmProvider, DemoLlmProvider.
abstract class LlmProvider {
  String get name;

  Future<String> generate({
    required String system,
    required String user,
    String? model,
  });

  Future<Map<String, dynamic>> structured({
    required String system,
    required String user,
    String? model,
  });
}

class LlmException implements Exception {
  final String message;
  LlmException(this.message);

  @override
  String toString() => message;
}
