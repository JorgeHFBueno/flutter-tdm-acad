import 'package:flutter/material.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

class TranslationTutorial extends StatefulWidget {
  const TranslationTutorial({super.key});

  @override
  State<TranslationTutorial> createState() => _TranslationTutorialState();
}

class _TranslationTutorialState extends State<TranslationTutorial> {
  final TranslateLanguage sourceLanguage = TranslateLanguage.english;
  final TranslateLanguage targetLanguage = TranslateLanguage.portuguese;

  final TextEditingController _textEditingController = TextEditingController();
  String _translatedText = '';
  late OnDeviceTranslator onDeviceTranslator;

  Future<String> translateText(String sourceText) async {
    final String translation =
    await onDeviceTranslator.translateText(sourceText);
    return translation;
  }

  @override
  void initState() {
    super.initState();
    onDeviceTranslator = OnDeviceTranslator(
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
    );
  }
  @override
  void dispose() {
    onDeviceTranslator.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Translation Tutorial'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextField(
              controller: _textEditingController,
              decoration: const InputDecoration(
                labelText: 'Enter text to translate',
              ),
            ),
            const SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: () async {
                final String sourceText = _textEditingController.text;
                final String translatedText = await translateText(sourceText);
                setState(() {
                  _translatedText = translatedText;
                });
              },
              child: const Text('Translate'),
            ),
            const SizedBox(height: 16.0),
            Text(
              'Translated Text:',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8.0),
            Text(
              _translatedText,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
