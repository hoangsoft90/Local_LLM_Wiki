import 'dart:convert';

import 'package:http/http.dart' as http;

import 'llm_provider.dart';
import 'output_parser.dart';

/// BYOK multi-provider via OpenRouter (openspec: ai-provider REQ-2/REQ-3).
class OpenRouterProvider implements LlmProvider {
  final String apiKey;
  final http.Client _client;

  OpenRouterProvider({required this.apiKey, http.Client? client})
      : _client = client ?? http.Client();

  static const baseUrl = 'https://openrouter.ai/api/v1/chat/completions';

  /// Curated model presets shown in Settings.
  static const modelPresets = [
    'anthropic/claude-sonnet-4',
    'anthropic/claude-haiku-4.5',
    'openai/gpt-4o',
    'openai/gpt-4o-mini',
    'google/gemini-2.5-pro',
    'google/gemini-2.5-flash',
    'deepseek/deepseek-chat',
    'meta-llama/llama-3.3-70b-instruct',
    'mistralai/mistral-small-3.1-24b-instruct',
    'qwen/qwen-2.5-72b-instruct',
  ];

  @override
  String get name => 'openrouter';

  @override
  Future<String> generate({
    required String system,
    required String user,
    String? model,
  }) async {
    final text = await _chat(system, user, model ?? modelPresets.first);
    return text;
  }

  @override
  Future<Map<String, dynamic>> structured({
    required String system,
    required String user,
    String? model,
  }) async {
    final text = await _chat(system, user, model ?? modelPresets.first);
    final json = extractJsonObject(text);
    if (json == null) {
      throw LlmException('Model returned no valid JSON: ${truncateText(text)}');
    }
    return json;
  }

  Future<String> _chat(String system, String user, String model) async {
    final resp = await _client
        .post(
          Uri.parse(baseUrl),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': model,
            'messages': [
              {'role': 'system', 'content': system},
              {'role': 'user', 'content': user},
            ],
            'temperature': 0.2,
            'max_tokens': 4096,
          }),
        )
        .timeout(const Duration(seconds: 120));

    if (resp.statusCode != 200) {
      throw LlmException(_mapError(resp.statusCode, resp.body));
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final choices = body['choices'] as List<dynamic>? ?? [];
    if (choices.isEmpty) {
      throw LlmException('OpenRouter returned no choices');
    }
    final content =
        (choices.first as Map<String, dynamic>)['message']
            as Map<String, dynamic>;
    return (content['content'] ?? '') as String;
  }

  String _mapError(int status, String body) {
    switch (status) {
      case 401:
        return 'Invalid OpenRouter API key. Check Settings.';
      case 402:
        return 'OpenRouter: insufficient credits.';
      case 429:
        return 'OpenRouter: rate limited. Try again shortly.';
      default:
        return 'OpenRouter error $status: ${truncateText(body)}';
    }
  }
}

String truncateText(String s, {int max = 200}) =>
    s.length <= max ? s : '${s.substring(0, max)}…';
