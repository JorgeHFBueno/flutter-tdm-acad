import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';

class ChatScreenAI extends StatefulWidget {
  const ChatScreenAI({super.key});

  @override
  State<ChatScreenAI> createState() => _ChatScreenStateAI();
}

class _ChatScreenStateAI extends State<ChatScreenAI> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;
  String? _responseText;

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _responseText = null;
    });

    try {
      final gemini = Gemini.instance;

      final result = await gemini.prompt(
        parts: [
          Part.text(text),
        ],
      );

      setState(() {
        _responseText = result?.output ?? 'Sem resposta da API.';
      });
    } catch (e) {
      setState(() {
        _responseText = 'Erro ao chamar a API: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat com Gemini'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Campo de entrada
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Digite sua mensagem...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _isLoading ? null : _sendMessage,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Loader
            if (_isLoading) const CircularProgressIndicator(),

            // Resposta
            if (_responseText != null && !_isLoading)
              Expanded(
                child: SingleChildScrollView(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey.shade200,
                    ),
                    child: Text(_responseText!),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
