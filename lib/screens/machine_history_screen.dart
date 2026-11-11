// ignore: depend_on_referenced_packages
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../components/observation_dialog.dart';
import '../data/exercise_catalog.dart';
import '../models/machine_configuration.dart';
import '../models/machine_event.dart';
import '../models/machine_history.dart';
import '../models/machine_catalog_item.dart';
import '../models/workout_session.dart';
import '../services/machine_history_service.dart';

export 'machine_catalog_screen.dart' show MachinesScreen;

class LegacyMachinesScreen extends StatefulWidget {
  const LegacyMachinesScreen({
    super.key,
    this.embedInScaffold = true,
    MachineService? service,
  }) : service = service ?? const MachineService();

  final bool embedInScaffold;
  final MachineService service;

  @override
  State<LegacyMachinesScreen> createState() => _LegacyMachinesScreenState();
}

class _LegacyMachinesScreenState extends State<LegacyMachinesScreen> {
  MachineService get _service => widget.service;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final content = user == null
        ? const Center(child: Text('Usuário não autenticado.'))
        : StreamBuilder<List<MachineProfile>>(
            stream: _service.watchForUser(user.uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Erro ao carregar Máquinas.'),
                      TextButton(
                        onPressed: () => setState(() {}),
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                );
              }
              final machines = snapshot.data ?? const <MachineProfile>[];
              if (machines.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Nenhuma máquina cadastrada.'),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Cadastrar máquina'),
                          onPressed: () =>
                              _openCreateDialog(user.uid, machines),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: machines.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Cadastrar máquina'),
                        onPressed: () => _openCreateDialog(user.uid, machines),
                      ),
                    );
                  }
                  final machine = machines[index - 1];
                  return _MachineCard(
                    machine: machine,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MachineDetailScreen(
                          ownerUid: user.uid,
                          exerciseId: machine.exerciseId,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );

    if (!widget.embedInScaffold) return content;
    return Scaffold(
      appBar: AppBar(title: const Text('Máquinas')),
      body: content,
    );
  }

  Future<void> _openCreateDialog(
    String ownerUid,
    List<MachineProfile> existingMachines,
  ) async {
    final existingIds =
        existingMachines.map((machine) => machine.exerciseId).toSet();

    final machine = await showDialog<MachineProfile>(
      context: context,
      builder: (dialogContext) => _CreateMachineDialog(
        ownerUid: ownerUid,
        existingIds: existingIds,
      ),
    );
    if (!mounted || machine == null) return;
    try {
      await _service.createMachine(machine);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Máquina cadastrada.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao cadastrar máquina.')),
      );
    }
  }
}

class _CreateMachineDialog extends StatefulWidget {
  const _CreateMachineDialog({
    required this.ownerUid,
    required this.existingIds,
  });

  final String ownerUid;
  final Set<String> existingIds;

  @override
  State<_CreateMachineDialog> createState() => _CreateMachineDialogState();
}

class _CreateMachineDialogState extends State<_CreateMachineDialog> {
  final _observationController = TextEditingController();
  final _setsController = TextEditingController();
  final _repetitionsController = TextEditingController();
  final _weightController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _setsFocus = FocusNode();
  final _repetitionsFocus = FocusNode();
  final _weightFocus = FocusNode();
  final _observationFocus = FocusNode();
  ExerciseCatalogItem? _selected;
  MachineIncrease? _previousIncrease;
  MachineIncrease? _lastIncrease;

  @override
  void dispose() {
    _observationController.dispose();
    _setsController.dispose();
    _repetitionsController.dispose();
    _weightController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    _setsFocus.dispose();
    _repetitionsFocus.dispose();
    _weightFocus.dispose();
    _observationFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final items = exerciseCatalog
        .where(
          (item) => query.isEmpty || item.name.toLowerCase().contains(query),
        )
        .toList();

    return AlertDialog(
      title: const Text('Cadastrar máquina'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom +
                  MediaQuery.viewPaddingOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Buscar exercício',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _setsFocus.requestFocus(),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selected?.id,
                  decoration: const InputDecoration(
                    labelText: 'Exercício',
                    border: OutlineInputBorder(),
                  ),
                  items: items
                      .map(
                        (item) => DropdownMenuItem<String>(
                          value: item.id,
                          child: Text('${item.name} - ${item.category}'),
                        ),
                      )
                      .toList(),
                  onChanged: (id) {
                    setState(() {
                      _selected =
                          id == null ? null : findExerciseCatalogItemById(id);
                    });
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _setsController,
                  focusNode: _setsFocus,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Series atuais',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => parsePositiveInt(value ?? '') == null
                      ? 'Informe um inteiro positivo'
                      : null,
                  onFieldSubmitted: (_) => _repetitionsFocus.requestFocus(),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _repetitionsController,
                  focusNode: _repetitionsFocus,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Repeticoes atuais',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => parsePositiveInt(value ?? '') == null
                      ? 'Informe um inteiro positivo'
                      : null,
                  onFieldSubmitted: (_) => _weightFocus.requestFocus(),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _weightController,
                  focusNode: _weightFocus,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Peso atual (kg)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      parsePositiveDecimal(value ?? '') == null
                          ? 'Informe um numero positivo'
                          : null,
                  onFieldSubmitted: (_) => _observationFocus.requestFocus(),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _observationController,
                  focusNode: _observationFocus,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'OBS',
                    border: OutlineInputBorder(),
                  ),
                  minLines: 2,
                  maxLines: 4,
                  onSubmitted: (_) => FocusScope.of(context).unfocus(),
                ),
                const SizedBox(height: 8),
                _increaseTile(
                  title: 'Penúltimo aumento',
                  increase: _previousIncrease,
                  onTap: () async {
                    final value = await showMachineIncreaseDialog(context);
                    if (!mounted || value == null) return;
                    setState(() => _previousIncrease = value);
                  },
                ),
                _increaseTile(
                  title: 'Último aumento',
                  increase: _lastIncrease,
                  onTap: () async {
                    final value = await showMachineIncreaseDialog(context);
                    if (!mounted || value == null) return;
                    setState(() => _lastIncrease = value);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: _submit,
          child: const Text('Cadastrar máquina'),
        ),
      ],
    );
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final item = _selected;
    if (item == null || widget.existingIds.contains(item.id)) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pop(
      MachineProfile(
        exerciseId: item.id,
        exerciseName: item.name,
        category: item.category,
        ownerUid: widget.ownerUid,
        observation: _observationController.text.trim(),
        currentSets: parsePositiveInt(_setsController.text),
        currentRepetitions: parsePositiveInt(_repetitionsController.text),
        currentWeightKg: parsePositiveDecimal(_weightController.text),
        lastIncrease: _lastIncrease,
        previousIncrease: _previousIncrease,
      ),
    );
  }
}

class _MachineCard extends StatelessWidget {
  const _MachineCard({required this.machine, required this.onTap});

  final MachineProfile machine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final observation = machine.observationText.trim();
    final config = resolveExerciseConfiguration(machine: machine);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                machine.exerciseName,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(machine.category),
              const SizedBox(height: 8),
              Text(config.compactLabel),
              if (!config.isComplete)
                Text(
                  'Configuracao incompleta',
                  style: TextStyle(color: Colors.orange[800]),
                ),
              const SizedBox(height: 8),
              Text('Realizado: ${machine.completionCount} vezes'),
              SelectableText(
                buildCompletionMarks(machine.completionCount),
                style: const TextStyle(fontFamily: 'monospace'),
              ),
              if (observation.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('OBS: $observation'),
              ],
              const SizedBox(height: 8),
              Text(
                'Último aumento: ${formatMachineIncrease(machine.lastIncrease)}',
              ),
              Text(
                'Penúltimo aumento: ${formatMachineIncrease(machine.previousIncrease)}',
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Abrir detalhes'),
                  onPressed: onTap,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MachineDetailScreen extends StatefulWidget {
  const MachineDetailScreen({
    super.key,
    required this.ownerUid,
    required this.exerciseId,
    MachineService? service,
    this.catalogItem,
  }) : service = service ?? const MachineService();

  final String ownerUid;
  final String exerciseId;
  final MachineService service;
  final MachineCatalogItem? catalogItem;

  @override
  State<MachineDetailScreen> createState() => _MachineDetailScreenState();
}

class _MachineDetailScreenState extends State<MachineDetailScreen> {
  static const int _eventPageSize = 50;

  MachineService get _service => widget.service;
  final List<MachineEvent> _events = [];
  dynamic _lastEventDocument;
  bool _isLoadingEvents = true;
  bool _isLoadingMoreEvents = false;
  bool _hasMoreEvents = false;
  bool _isWritingMachineEvent = false;
  String _eventFilter = 'all';
  Object? _eventError;

  @override
  void initState() {
    super.initState();
    _initializeAndLoadEvents();
  }

  Future<void> _initializeAndLoadEvents() async {
    setState(() {
      _isLoadingEvents = true;
      _eventError = null;
    });
    try {
      await _service.ensureEventTrackingInitialized(
        ownerUid: widget.ownerUid,
        exerciseId: widget.exerciseId,
      );
      final page = await _service.getEvents(
        ownerUid: widget.ownerUid,
        exerciseId: widget.exerciseId,
        limit: _eventPageSize,
      );
      if (!mounted) return;
      setState(() {
        _events
          ..clear()
          ..addAll(page.events);
        _lastEventDocument = page.lastDocument;
        _hasMoreEvents = page.hasMore;
        _isLoadingEvents = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _eventError = error;
        _isLoadingEvents = false;
      });
    }
  }

  Future<void> _loadMoreEvents() async {
    if (_isLoadingMoreEvents || !_hasMoreEvents) return;
    setState(() => _isLoadingMoreEvents = true);
    try {
      final page = await _service.loadMoreEvents(
        ownerUid: widget.ownerUid,
        exerciseId: widget.exerciseId,
        startAfter: _lastEventDocument,
        limit: _eventPageSize,
      );
      if (!mounted) return;
      setState(() {
        _events.addAll(page.events);
        _lastEventDocument = page.lastDocument ?? _lastEventDocument;
        _hasMoreEvents = page.hasMore;
        _isLoadingMoreEvents = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMoreEvents = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao carregar eventos.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalhes da máquina')),
      body: StreamBuilder<MachineProfile?>(
        stream: _service.watchByExerciseId(widget.ownerUid, widget.exerciseId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Erro ao carregar máquina.'));
          }
          final machine = snapshot.data;
          if (machine == null) {
            return const Center(child: Text('Máquina não encontrada.'));
          }
          final observation = machine.observationText;
          final config = resolveExerciseConfiguration(machine: machine);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                widget.catalogItem?.popularName ?? machine.exerciseName,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              if (widget.catalogItem != null) ...[
                Text(widget.catalogItem!.scientificName),
                Text(
                    '${MachineCatalogCategory.label(widget.catalogItem!.category)} · '
                    '${MachineCatalogType.label(widget.catalogItem!.type)}'),
              ] else
                Text(machine.category),
              const SizedBox(height: 12),
              Text('Configuracao atual: ${config.compactLabel}'),
              if (!config.isComplete)
                Text(
                  'Configuracao incompleta',
                  style: TextStyle(color: Colors.orange[800]),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.tune),
                  label: const Text('Editar configuracao'),
                  onPressed: () => _editCurrentConfiguration(machine),
                ),
              ),
              const SizedBox(height: 12),
              Text('Realizado: ${machine.completionCount} vezes'),
              SelectableText(
                _historyLine(machine),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 16),
              ),
              if ((machine.eventTrackingBaselineCount ?? 0) > 0)
                Text(
                  'Baseline anterior: ${machine.eventTrackingBaselineCount}',
                ),
              const SizedBox(height: 16),
              Text('OBS: ${observation.isEmpty ? 'Sem OBS' : observation}'),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.notes),
                  label: const Text('Editar OBS'),
                  onPressed: () => _editObservation(machine),
                ),
              ),
              const Divider(),
              _buildIncreaseActions(
                machine,
                'Último aumento',
                'lastIncrease',
                machine.lastIncrease,
              ),
              _buildIncreaseActions(
                machine,
                'Penúltimo aumento',
                'previousIncrease',
                machine.previousIncrease,
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.trending_up),
                label: const Text('Registrar aumento'),
                onPressed: _isWritingMachineEvent
                    ? null
                    : () => _registerIncrease(machine),
              ),
              const Divider(),
              _buildEventsSection(),
            ],
          );
        },
      ),
    );
  }

  String _historyLine(MachineProfile machine) {
    final completionEvents = _events
        .where((event) => event.type == MachineEventType.completion)
        .toList()
      ..sort((a, b) {
        final left = a.occurredAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final right = b.occurredAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return left.compareTo(right);
      });
    return buildMachineEventHistoryLine(
      machine.eventTrackingBaselineCount ?? machine.completionCount,
      completionEvents.map((event) => event.completionSymbol),
    );
  }

  Widget _buildEventsSection() {
    if (_isLoadingEvents) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_eventError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Erro ao carregar eventos.'),
          TextButton(
            onPressed: _initializeAndLoadEvents,
            child: const Text('Tentar novamente'),
          ),
        ],
      );
    }
    final filtered = _filteredEvents();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Eventos',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Todos'),
              selected: _eventFilter == 'all',
              onSelected: (_) => setState(() => _eventFilter = 'all'),
            ),
            ChoiceChip(
              label: const Text('Execucoes'),
              selected: _eventFilter == 'completion',
              onSelected: (_) => setState(() => _eventFilter = 'completion'),
            ),
            ChoiceChip(
              label: const Text('Aumentos'),
              selected: _eventFilter == 'increase',
              onSelected: (_) => setState(() => _eventFilter = 'increase'),
            ),
            ChoiceChip(
              label: const Text('OBS'),
              selected: _eventFilter == 'observation',
              onSelected: (_) => setState(() => _eventFilter = 'observation'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (filtered.isEmpty)
          const Text('Nenhum evento registrado.')
        else
          for (final event in filtered) _MachineEventTile(event: event),
        if (_hasMoreEvents)
          Center(
            child: TextButton(
              onPressed: _isLoadingMoreEvents ? null : _loadMoreEvents,
              child: Text(
                _isLoadingMoreEvents ? 'Carregando...' : 'Carregar mais',
              ),
            ),
          ),
      ],
    );
  }

  List<MachineEvent> _filteredEvents() {
    switch (_eventFilter) {
      case 'completion':
        return _events.where((event) => event.isCompletion).toList();
      case 'increase':
        return _events.where((event) => event.isIncrease).toList();
      case 'observation':
        return _events.where((event) => event.isObservation).toList();
      default:
        return List.of(_events);
    }
  }

  Widget _buildIncreaseActions(
    MachineProfile machine,
    String title,
    String slot,
    MachineIncrease? increase,
  ) {
    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: Text(formatMachineIncrease(increase, includeYear: true)),
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              tooltip: 'Editar',
              icon: const Icon(Icons.edit),
              onPressed: () => _editIncrease(machine, slot, increase),
            ),
            IconButton(
              tooltip: 'Limpar',
              icon: const Icon(Icons.delete_outline),
              onPressed:
                  increase == null ? null : () => _clearIncrease(machine, slot),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editObservation(MachineProfile machine) async {
    if (_isWritingMachineEvent) return;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => ObservationDialog(
        initialObservation: machine.observationText,
      ),
    );
    if (result == null) return;
    setState(() => _isWritingMachineEvent = true);
    try {
      await _service.updateObservation(
        ownerUid: machine.ownerUid,
        exerciseId: machine.exerciseId,
        exerciseName: machine.exerciseName,
        category: machine.category,
        observation: result.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OBS atualizada.')),
      );
      await _initializeAndLoadEvents();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao salvar OBS. Tente novamente.')),
      );
    } finally {
      if (mounted) setState(() => _isWritingMachineEvent = false);
    }
  }

  Future<void> _editCurrentConfiguration(MachineProfile machine) async {
    final result = await showMachineConfigurationDialog(
      context,
      machine: machine,
      requireComplete: false,
    );
    if (result == null) return;
    try {
      await _service.updateCurrentConfiguration(
        ownerUid: machine.ownerUid,
        exerciseId: machine.exerciseId,
        exerciseName: machine.exerciseName,
        category: machine.category,
        currentSets: result.currentSets,
        currentRepetitions: result.currentRepetitions,
        currentWeightKg: result.currentWeightKg,
      );
      await _service.updateObservation(
        ownerUid: machine.ownerUid,
        exerciseId: machine.exerciseId,
        exerciseName: machine.exerciseName,
        category: machine.category,
        observation: result.observation,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuracao atualizada.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao salvar configuracao.')),
      );
    }
  }

  Future<void> _registerIncrease(MachineProfile machine) async {
    if (_isWritingMachineEvent) return;
    final increase = await showMachineIncreaseDialog(context);
    if (increase == null) return;
    setState(() => _isWritingMachineEvent = true);
    try {
      await _service.registerIncrease(
        ownerUid: machine.ownerUid,
        exerciseId: machine.exerciseId,
        exerciseName: machine.exerciseName,
        category: machine.category,
        increase: increase,
      );
      await _initializeAndLoadEvents();
    } finally {
      if (mounted) setState(() => _isWritingMachineEvent = false);
    }
  }

  Future<void> _editIncrease(
    MachineProfile machine,
    String slot,
    MachineIncrease? current,
  ) async {
    if (_isWritingMachineEvent) return;
    final increase = await showMachineIncreaseDialog(context, initial: current);
    if (increase == null) return;
    setState(() => _isWritingMachineEvent = true);
    try {
      await _service.updateIncreaseSlot(
        ownerUid: machine.ownerUid,
        exerciseId: machine.exerciseId,
        slot: slot,
        increase: increase,
      );
      await _initializeAndLoadEvents();
    } finally {
      if (mounted) setState(() => _isWritingMachineEvent = false);
    }
  }

  Future<void> _clearIncrease(MachineProfile machine, String slot) async {
    if (_isWritingMachineEvent) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpar aumento'),
        content: const Text('Deseja limpar este aumento?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isWritingMachineEvent = true);
    try {
      await _service.updateIncreaseSlot(
        ownerUid: machine.ownerUid,
        exerciseId: machine.exerciseId,
        slot: slot,
      );
      await _initializeAndLoadEvents();
    } finally {
      if (mounted) setState(() => _isWritingMachineEvent = false);
    }
  }
}

Widget _increaseTile({
  required String title,
  required MachineIncrease? increase,
  required VoidCallback onTap,
}) {
  return ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(title),
    subtitle: Text(formatMachineIncrease(increase, includeYear: true)),
    trailing: const Icon(Icons.edit),
    onTap: onTap,
  );
}

class _MachineEventTile extends StatelessWidget {
  const _MachineEventTile({required this.event});

  final MachineEvent event;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(_title),
      subtitle: _subtitle == null ? null : Text(_subtitle!),
    );
  }

  String get _title {
    final date = _formatDate(event.occurredAt);
    switch (event.type) {
      case MachineEventType.completion:
        return '$date - ${PerceivedEffort.labelFor(event.perception)} - ${event.completionSymbol}';
      case MachineEventType.weightIncreased:
        return '$date - Aumentou o peso para ${_formatNumber(event.newValue)} kg';
      case MachineEventType.setsIncreased:
        return '$date - Aumentou para ${_formatInteger(event.newValue)} series';
      case MachineEventType.repetitionsIncreased:
        return '$date - Aumentou para ${_formatInteger(event.newValue)} repeticoes';
      case MachineEventType.observationChanged:
        return '$date - OBS alterada';
      default:
        return '$date - Evento desconhecido';
    }
  }

  String? get _subtitle {
    if (event.type == MachineEventType.completion) {
      if (PerceivedEffort.isSkipped(event.perception)) return null;
      return '${event.performedSetCount ?? 0} series • '
          '${event.performedTotalRepetitions ?? 0} repeticoes • '
          '${_formatNumber(event.performedVolume)} kg de volume';
    }
    if (event.type == MachineEventType.observationChanged) {
      return '${_obs(event.previousObservation)} -> ${_obs(event.newObservation)}';
    }
    if (event.previousValue != null) {
      return '${_formatNumber(event.previousValue)} -> ${_formatNumber(event.newValue)}';
    }
    return null;
  }

  String _obs(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? 'Sem OBS' : text;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '--/--';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
  }

  String _formatInteger(double? value) {
    if (value == null) return '0';
    return value.round().toString();
  }

  String _formatNumber(double? value) {
    if (value == null) return '0';
    return formatCompactNumber(value);
  }
}

class MachineConfigurationResult {
  final int? currentSets;
  final int? currentRepetitions;
  final double? currentWeightKg;
  final String observation;

  const MachineConfigurationResult({
    required this.currentSets,
    required this.currentRepetitions,
    required this.currentWeightKg,
    required this.observation,
  });
}

Future<MachineConfigurationResult?> showMachineConfigurationDialog(
  BuildContext context, {
  MachineProfile? machine,
  String? exerciseName,
  bool requireComplete = false,
}) {
  return showDialog<MachineConfigurationResult>(
    context: context,
    builder: (dialogContext) => _MachineConfigurationDialog(
      machine: machine,
      exerciseName: exerciseName,
      requireComplete: requireComplete,
    ),
  );
}

class _MachineConfigurationDialog extends StatefulWidget {
  const _MachineConfigurationDialog({
    this.machine,
    this.exerciseName,
    required this.requireComplete,
  });

  final MachineProfile? machine;
  final String? exerciseName;
  final bool requireComplete;

  @override
  State<_MachineConfigurationDialog> createState() =>
      _MachineConfigurationDialogState();
}

class _MachineConfigurationDialogState
    extends State<_MachineConfigurationDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _setsController;
  late final TextEditingController _repetitionsController;
  late final TextEditingController _weightController;
  late final TextEditingController _observationController;
  final _setsFocus = FocusNode();
  final _repetitionsFocus = FocusNode();
  final _weightFocus = FocusNode();
  final _observationFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    final machine = widget.machine;
    _setsController = TextEditingController(
      text: machine?.currentSets?.toString() ?? '',
    );
    _repetitionsController = TextEditingController(
      text: machine?.currentRepetitions?.toString() ?? '',
    );
    _weightController = TextEditingController(
      text: machine?.currentWeightKg == null
          ? ''
          : formatCompactNumber(machine!.currentWeightKg!),
    );
    _observationController = TextEditingController(
      text: machine?.observationText ?? '',
    );
  }

  @override
  void dispose() {
    _setsController.dispose();
    _repetitionsController.dispose();
    _weightController.dispose();
    _observationController.dispose();
    _setsFocus.dispose();
    _repetitionsFocus.dispose();
    _weightFocus.dispose();
    _observationFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.exerciseName ?? 'Configuracao atual'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom +
                MediaQuery.viewPaddingOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _setsController,
                focusNode: _setsFocus,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Series atuais',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => _validateOptionalInt(value ?? ''),
                onFieldSubmitted: (_) => _repetitionsFocus.requestFocus(),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _repetitionsController,
                focusNode: _repetitionsFocus,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Repeticoes atuais',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => _validateOptionalInt(value ?? ''),
                onFieldSubmitted: (_) => _weightFocus.requestFocus(),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _weightController,
                focusNode: _weightFocus,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Peso atual (kg)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => _validateOptionalDecimal(value ?? ''),
                onFieldSubmitted: (_) => _observationFocus.requestFocus(),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _observationController,
                focusNode: _observationFocus,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'OBS',
                  border: OutlineInputBorder(),
                ),
                minLines: 2,
                maxLines: 4,
                onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: _submit,
          child: const Text('Salvar'),
        ),
      ],
    );
  }

  String? _validateOptionalInt(String value) {
    if (!widget.requireComplete && value.trim().isEmpty) return null;
    return parsePositiveInt(value) == null
        ? 'Informe um inteiro positivo'
        : null;
  }

  String? _validateOptionalDecimal(String value) {
    if (!widget.requireComplete && value.trim().isEmpty) return null;
    return parsePositiveDecimal(value) == null
        ? 'Informe um numero positivo'
        : null;
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      MachineConfigurationResult(
        currentSets: _setsController.text.trim().isEmpty
            ? null
            : parsePositiveInt(_setsController.text),
        currentRepetitions: _repetitionsController.text.trim().isEmpty
            ? null
            : parsePositiveInt(_repetitionsController.text),
        currentWeightKg: _weightController.text.trim().isEmpty
            ? null
            : parsePositiveDecimal(_weightController.text),
        observation: _observationController.text.trim(),
      ),
    );
  }
}

Future<MachineIncrease?> showMachineIncreaseDialog(
  BuildContext context, {
  MachineIncrease? initial,
}) {
  return showDialog<MachineIncrease>(
    context: context,
    builder: (dialogContext) => _MachineIncreaseDialog(initial: initial),
  );
}

class _MachineIncreaseDialog extends StatefulWidget {
  const _MachineIncreaseDialog({this.initial});

  final MachineIncrease? initial;

  @override
  State<_MachineIncreaseDialog> createState() => _MachineIncreaseDialogState();
}

class _MachineIncreaseDialogState extends State<_MachineIncreaseDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _selectedType;
  late DateTime _selectedDate;
  late final TextEditingController _valueController;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initial?.type ?? MachineIncreaseType.weight;
    _selectedDate = widget.initial?.date ?? DateTime.now();
    _valueController = TextEditingController(
      text: widget.initial == null
          ? ''
          : widget.initial!.value.toString().replaceAll('.', ','),
    );
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}';
    return AlertDialog(
      title: const Text('Registrar aumento'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Tipo do aumento',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: MachineIncreaseType.weight,
                    child: Text('Peso'),
                  ),
                  DropdownMenuItem(
                    value: MachineIncreaseType.sets,
                    child: Text('Séries'),
                  ),
                  DropdownMenuItem(
                    value: MachineIncreaseType.repetitions,
                    child: Text('Repetições'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedType = value;
                  });
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _valueController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: _selectedType == MachineIncreaseType.weight
                      ? 'Valor (kg)'
                      : 'Novo total',
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  final normalized = (value ?? '').replaceAll(',', '.');
                  final parsed = double.tryParse(normalized);
                  if (parsed == null || parsed <= 0) {
                    return 'Informe um valor positivo';
                  }
                  if ((_selectedType == MachineIncreaseType.sets ||
                          _selectedType == MachineIncreaseType.repetitions) &&
                      parsed != parsed.roundToDouble()) {
                    return 'Informe um número inteiro';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Data'),
                subtitle: Text(dateLabel),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (!mounted || picked == null) return;
                  setState(() {
                    _selectedDate = picked;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: _submit,
          child: const Text('Salvar'),
        ),
      ],
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final value = double.parse(_valueController.text.replaceAll(',', '.'));
    Navigator.of(context).pop(
      MachineIncrease(
        type: _selectedType,
        value: value,
        date: _selectedDate,
      ),
    );
  }
}
