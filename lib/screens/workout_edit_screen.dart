import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/machine_configuration.dart';
import '../models/machine_history.dart';
import '../models/workout.dart';
import '../services/machine_history_service.dart';
import '../services/workout_service.dart';
import 'machine_history_screen.dart';

class WorkoutEditScreen extends StatefulWidget {
  const WorkoutEditScreen({super.key, required this.workout});

  final Workout workout;

  @override
  State<WorkoutEditScreen> createState() => _WorkoutEditScreenState();
}

class _WorkoutEditScreenState extends State<WorkoutEditScreen> {
  late final TextEditingController _nameController;
  final WorkoutService _workoutService = const WorkoutService();
  final MachineService _machineService = const MachineService();
  late List<String> _selectedMachineIds;
  List<MachineProfile> _machines = const [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.workout.name);
    _selectedMachineIds = List.of(widget.workout.machineIds);
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
      await _workoutService.updateWorkout(
        Workout(
          id: widget.workout.id,
          name: _nameController.text.trim(),
          ownerUid: widget.workout.ownerUid,
          machineIds: _selectedMachineIds,
          createdAt: widget.workout.createdAt,
          updatedAt: widget.workout.updatedAt,
        ),
      );
      if (!mounted) return;
      _showSnackBar('Treino atualizado com sucesso!');
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Erro ao atualizar treino. Tente novamente.');
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

  void _removeMissing(String id) {
    setState(() => _selectedMachineIds.remove(id));
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
    return Scaffold(
      appBar: AppBar(title: const Text('Editar treino')),
      body: user == null
          ? const Center(child: Text('Usuario nao autenticado'))
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final machinesById = {
      for (final machine in _machines) machine.exerciseId: machine,
    };
    final missingIds = _selectedMachineIds
        .where((id) => !machinesById.containsKey(id))
        .toList(growable: false);

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
          const SizedBox(height: 8),
          const Text(
            'A configuracao pertence a Maquina e e compartilhada por todos os treinos.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              children: [
                if (_machines.isEmpty)
                  ListTile(
                    title: const Text('Nenhuma maquina cadastrada.'),
                    trailing: TextButton.icon(
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
                  ),
                for (final machine in _machines)
                  CheckboxListTile(
                    value: _selectedMachineIds.contains(machine.exerciseId),
                    title: Text(machine.exerciseName),
                    subtitle: _MachineSubtitle(machine: machine),
                    onChanged: (checked) =>
                        _toggleMachine(machine.exerciseId, checked == true),
                  ),
                if (missingIds.isNotEmpty) ...[
                  const Divider(),
                  Text(
                    'Uma ou mais maquinas deste treino nao estao disponiveis. Remova ou substitua antes de iniciar.',
                    style: TextStyle(color: Colors.orange[800]),
                  ),
                  for (final id in missingIds)
                    ListTile(
                      leading: const Icon(Icons.error_outline),
                      title: Text('Referencia ausente: $id'),
                      trailing: IconButton(
                        tooltip: 'Remover referencia',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _removeMissing(id),
                      ),
                    ),
                ],
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
                      leading: Text('${index + 1}'),
                      title: Text(
                        machinesById[_selectedMachineIds[index]]
                                ?.exerciseName ??
                            'Referencia ausente: ${_selectedMachineIds[index]}',
                      ),
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
                  : const Text('Salvar alteracoes'),
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
