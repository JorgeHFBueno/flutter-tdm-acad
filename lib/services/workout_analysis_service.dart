import 'package:flutter_gemini/flutter_gemini.dart';

class WorkoutAnalysisService {
  WorkoutAnalysisService({Gemini? gemini}) : _gemini = gemini;

  // Resolved lazily: Gemini is not initialized on web.
  final Gemini? _gemini;

  Future<String> analyzeText(String prompt) async {
    final gemini = _gemini ?? Gemini.instance;
    final result = await gemini.prompt(parts: [Part.text(prompt)]);
    final output = result?.output?.trim();
    if (output == null || output.isEmpty) {
      throw Exception('Resposta vazia do Gemini');
    }
    return output;
  }
}
