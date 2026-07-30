import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/machine_configuration.dart';
import '../models/machine_history.dart';
import '../models/workout.dart';
import '../services/machine_history_service.dart';
import '../services/workout_service.dart';
import 'machine_history_screen.dart';

class WorkoutCreationScreen extends StatefulWidget {
  const WorkoutCreationScreen({super.key, this.embedInScaffold = true});

  final bool embedInScaffold;

  @override
  State<WorkoutCreationScreen> createState() => _WorkoutCreationScreenState();
}

class _WorkoutCreationScreenState extends State<WorkoutCreationScreen> {
  final TextEditingController _nameController = TextEditingController();
  final WorkoutService _workoutService = const WorkoutService();
  final MachineService _machineService = const MachineService();
  final List<String> _selectedMachineIds = [];
  List<MachineProfile> _machines = const [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadMachines();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadMachines() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final machines = await _machineService.listForUser(user.uid);
      if (!mounted) return;
      setState(() {
        _machines = machines;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar('Erro ao carregar maquinas.');
    }
  }

  Future<void> _saveWorkout() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Usuario nao autenticado');
      return;
    }
    if (_nameController.text.trim().isEmpty) {
      _showSnackBar('Informe o nome do treino');
      return;
    }
    if (_selectedMachineIds.isEmpty) {
      _showSnackBar('Selecione pelo menos uma maquina');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _workoutService.createWorkout(
        Workout(
          name: _nameController.text.trim(),
          ownerUid: user.uid,
          machineIds: _selectedMachineIds,
        ),
      );
      if (!mounted) return;
      _showSnackBar('Treino salvo com sucesso!');
      setState(() {
        _nameController.clear();
        _selectedMachineIds.clear();
      });
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Erro ao salvar treino. Tente novamente.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _toggleMachine(String id, bool selected) {
    setState(() {
      _selectedMachineIds.remove(id);
      if (selected) {
        _selectedMachineIds.add(id);
      }
    });
  }

  void _moveSelected(int index, int delta) {
    final target = index + delta;
    if (index < 0 || target < 0 || target >= _selectedMachineIds.length) {
      return;
    }
    setState(() {
      final id = _selectedMachineIds.removeAt(index);
      _selectedMachineIds.insert(target, id);
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final content = user == null
        ? const Center(child: Text('Usuario nao autenticado'))
        : _buildContent();
    if (!widget.embedInScaffold) return content;
    return Scaffold(
      appBar: AppBar(title: const Text('Criar treino')),
      body: content,
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_machines.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Cadastre uma maquina antes de criar um treino.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Cadastrar maquina'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MachinesScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
    }

    final machinesById = {
      for (final machine in _machines) machine.exerciseId: machine,
    };

    return Padding(
      padding: const EdgeInsets.all(16),
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
          const SizedBox(height: 12),
          const Text(
            'Maquinas do treino',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children: [
                for (final machine in _machines)
                  CheckboxListTile(
                    value: _selectedMachineIds.contains(machine.exerciseId),
                    title: Text(machine.exerciseName),
                    subtitle: _MachineSubtitle(machine: machine),
                    onChanged: (checked) =>
                        _toggleMachine(machine.exerciseId, checked == true),
                  ),
                if (_selectedMachineIds.isNotEmpty) ...[
                  const Divider(),
                  const Text(
                    'Ordem da ficha',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  for (var index = 0;
                      index < _selectedMachineIds.length;
                      index++)
                    ListTile(
                      title: Text(
                        machinesById[_selectedMachineIds[index]]
                                ?.exerciseName ??
                            _selectedMachineIds[index],
                      ),
                      leading: Text('${index + 1}'),
                      trailing: Wrap(
                        children: [
                          IconButton(
                            tooltip: 'Mover para cima',
                            icon: const Icon(Icons.keyboard_arrow_up),
                            onPressed: index == 0
                                ? null
                                : () => _moveSelected(index, -1),
                          ),
                          IconButton(
                            tooltip: 'Mover para baixo',
                            icon: const Icon(Icons.keyboard_arrow_down),
                            onPressed: index == _selectedMachineIds.length - 1
                                ? null
                                : () => _moveSelected(index, 1),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
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
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Salvar treino'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MachineSubtitle extends StatelessWidget {
  const _MachineSubtitle({required this.machine});

  final MachineProfile machine;

  @override
  Widget build(BuildContext context) {
    final config = resolveExerciseConfiguration(machine: machine);
    final observation = machine.observationText.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${machine.category} - ${config.compactLabel}'),
        if (observation.isNotEmpty) Text('OBS: $observation'),
      ],
    );
  }
}
