import 'package:flutter/material.dart';

class ObservationDialog extends StatefulWidget {
  const ObservationDialog({
    super.key,
    required this.initialObservation,
    this.title = 'Editar OBS',
  });

  final String initialObservation;
  final String title;

  @override
  State<ObservationDialog> createState() => _ObservationDialogState();
}

class _ObservationDialogState extends State<ObservationDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialObservation);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          labelText: 'OBS',
          border: OutlineInputBorder(),
        ),
        minLines: 3,
        maxLines: 5,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Salvar OBS'),
        ),
      ],
    );
  }
}
