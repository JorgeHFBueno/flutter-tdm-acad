import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/workout_analysis_log.dart';
import '../services/workout_analysis_log_service.dart';
import 'workout_analysis_detail_screen.dart';

class WorkoutAnalysisHistoryScreen extends StatelessWidget {
  WorkoutAnalysisHistoryScreen({super.key});

  final WorkoutAnalysisLogService _logService = WorkoutAnalysisLogService();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de análises'),
      ),
      body: user == null
          ? const Center(child: Text('Usuário não autenticado.'))
          : StreamBuilder<List<WorkoutAnalysisLog>>(
        stream: _logService.getLogsForUser(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(
              child:
              Text('Erro ao carregar histórico de análises da IA.'),
            );
          }

          final logs = snapshot.data ?? [];
          if (logs.isEmpty) {
            return const Center(
              child: Text('Você ainda não possui análises salvas.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              return _LogCard(log: log);
            },
          );
        },
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  const _LogCard({required this.log});

  final WorkoutAnalysisLog log;

  String _formatDate(DateTime? date) {
    if (date == null) return 'Data não informada';
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'history':
        return 'Histórico';
      case 'session':
        return 'Sessão';
      default:
        return type;
    }
  }

  String _responsePreview(String response) {
    final lines = response.trim().split('\n');
    if (lines.isEmpty) return '';
    final preview = lines.first;
    if (preview.length > 120) {
      return '${preview.substring(0, 120)}...';
    }
    return preview;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: const Icon(Icons.analytics_outlined),
        title: Text(log.workoutName ?? 'Treino sem nome'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_typeLabel(log.type)} • ${_formatDate(log.createdAt)}'),
            const SizedBox(height: 4),
            Text(_responsePreview(log.response)),
          ],
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => WorkoutAnalysisDetailScreen(log: log),
            ),
          );
        },
      ),
    );
  }
}