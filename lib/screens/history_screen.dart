import 'package:flutter/material.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, this.embedInScaffold = true});

  final bool embedInScaffold;

  @override
  Widget build(BuildContext context) {
    final content = const Center(
      child: Text('Tela de histórico em construção'),
    );

    if (!embedInScaffold) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Histórico'),
      ),
      body: const Center(
        child: Text(
            'Tela de histórico em construção (buscará workout_history por ownerUid).'),
      ),
    );
  }
}