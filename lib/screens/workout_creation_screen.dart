import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/workout.dart';
import '../services/workout_service.dart';

class WorkoutCreationScreen extends StatefulWidget {
  const WorkoutCreationScreen({super.key, this.embedInScaffold = true});

  final bool embedInScaffold;
  @override
  State<WorkoutCreationScreen> createState() => _WorkoutCreationScreenState();
}

class _WorkoutCreationScreenState extends State<WorkoutCreationScreen> {
  final List<String> _availableExercises = const [
    "Supino reto (máquina)",
    "Puxada frente",
    "Leg press 45º",
    "Remada baixa",
    "Desenvolvimento ombro",
  ];

  final Map<String, int> _selectedExercisesWithWeight = {};
  final TextEditingController _nameController = TextEditingController();
  final WorkoutService _workoutService = WorkoutService();
  bool _isSaving = false;
  final List<int> _availableWeights =
  List<int>.generate(19, (index) => 10 + index * 5);

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveWorkout() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Usuário não autenticado');
      return;
    }

    if (_nameController.text.trim().isEmpty) {
      _showSnackBar('Informe o nome do treino');
      return;
    }

    if (_selectedExercisesWithWeight.isEmpty) {
      _showSnackBar('Selecione pelo menos um exercício');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final workout = Workout(
      name: _nameController.text.trim(),
      exercises: _selectedExercisesWithWeight.entries
          .map(
            (entry) => WorkoutExercise(
          name: entry.key,
          defaultWeightKg: entry.value,
        ),
      )
          .toList(),
      ownerUid: user.uid,
      ownerName: user.displayName ?? user.email ?? 'Usuário',
    );

    try {
      await _workoutService.createWorkout(workout);
      _showSnackBar('Treino salvo com sucesso!');
      setState(() {
        _selectedExercisesWithWeight.clear();
        _nameController.clear();
      });
    } catch (e) {
      _showSnackBar('Erro ao salvar treino. Tente novamente.');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return _wrapContent(
        const Center(
          child: Text('Usuário não autenticado'),
        ),
      );
    }
    final content = _buildContent(user);
    if (!widget.embedInScaffold) {
      return content;
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar treino'),
      ),
      body: content,
    );
  }

  Widget _wrapContent(Widget child) {
    if (widget.embedInScaffold) {
      return Scaffold(body: child);
    }
    return child;
  }

  Widget _buildContent(User user) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nome do treino',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Escolha os exercícios:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: _availableExercises.length,
              itemBuilder: (context, index) {
                final exercise = _availableExercises[index];
                final isSelected =
                _selectedExercisesWithWeight.containsKey(exercise);
                final selectedWeight =
                    _selectedExercisesWithWeight[exercise] ?? 10;
                return CheckboxListTile(
                  title: Text(exercise),
                  subtitle: isSelected
                      ? DropdownButton<int>(
                    value: selectedWeight,
                    items: _availableWeights
                        .map(
                          (weight) => DropdownMenuItem<int>(
                        value: weight,
                        child: Text('$weight kg'),
                      ),
                    )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedExercisesWithWeight[exercise] = value;
                      });
                    },
                  )
                      : null,
                  value: isSelected,
                  onChanged: (checked) {
                    setState(() {
                      if (checked == true) {
                        _selectedExercisesWithWeight[exercise] = selectedWeight;
                      } else {
                        _selectedExercisesWithWeight.remove(exercise);
                      }
                    });
                  },
                );
              },
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveWorkout,
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Salvar treino'),
            ),
          ),
        ],
      ),
    );
  }
}
