import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/workout_analysis_log.dart';

class WorkoutAnalysisDetailScreen extends StatelessWidget {
  final WorkoutAnalysisLog log;

  const WorkoutAnalysisDetailScreen({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(log.workoutName ?? 'Análise de treino'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copiar texto da análise',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: log.response));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Texto da análise copiado')),
                );
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Text(
            log.response,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}