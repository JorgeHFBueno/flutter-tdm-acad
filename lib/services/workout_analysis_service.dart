import 'package:flutter_gemini/flutter_gemini.dart';

class WorkoutAnalysisService {
  WorkoutAnalysisService({Gemini? gemini}) : _gemini = gemini ?? Gemini.instance;

  final Gemini _gemini;

  Future<String> analyzeText(String prompt) async {
    final result = await _gemini.prompt(parts: [Part.text(prompt)]);
    final output = result?.output?.trim();
    if (output == null || output.isEmpty) {
      throw Exception('Resposta vazia do Gemini');
    }
    return output;
  }
}