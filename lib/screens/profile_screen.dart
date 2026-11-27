import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/body_profile.dart';
import '../models/cardio.dart' show parseDecimal;
import '../services/body_profile_service.dart';

/// Birth date, height, sex, goal and the weighing history.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.uid, this.service});

  final String uid;
  final BodyProfileService? service;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final BodyProfileService _service =
      widget.service ?? BodyProfileService();
  final _heightController = TextEditingController();
  final _dateFormat = DateFormat('dd/MM/yyyy');
  DateTime? _birthDate;
  String? _sex;
  String? _goal;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _service.watchProfile(widget.uid).first.then((profile) {
      if (!mounted) return;
      setState(() {
        _birthDate = profile.birthDate;
        _sex = profile.sex;
        _goal = profile.goal;
        _heightController.text =
            profile.heightM?.toStringAsFixed(2).replaceAll('.', ',') ?? '';
        _loading = false;
      });
    }, onError: (_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    _heightController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(2000),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _save() async {
    final heightText = _heightController.text.trim();
    final height = heightText.isEmpty ? null : parseDecimal(heightText);
    if (heightText.isNotEmpty &&
        (height == null || height < 1 || height > 2.5)) {
      _showSnackBar('Altura em metros, por exemplo 1,77.');
      return;
    }
    setState(() => _saving = true);
    try {
      await _service.saveProfile(
        widget.uid,
        BodyProfile(
          birthDate: _birthDate,
          heightM: height,
          sex: _sex,
          goal: _goal,
        ),
      );
      _showSnackBar('Perfil salvo.');
    } catch (_) {
      _showSnackBar('Erro ao salvar o perfil.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addWeight() async {
    final controller = TextEditingController();
    var date = DateTime.now();
    final entry = await showDialog<BodyWeightEntry>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final weight = parseDecimal(controller.text);
          final valid = weight != null && weight >= 20 && weight <= 300;
          return AlertDialog(
            title: const Text('Registrar pesagem'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Peso (kg)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event),
                  title: Text(_dateFormat.format(date)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setDialogState(() => date = picked);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: !valid
                    ? null
                    : () => Navigator.of(ctx).pop(
                          BodyWeightEntry(date: date, weightKg: weight),
                        ),
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      ),
    );
    controller.dispose();
    if (entry == null) return;
    try {
      await _service.addWeight(widget.uid, entry);
    } catch (_) {
      _showSnackBar('Erro ao salvar a pesagem.');
    }
  }

  Future<void> _deleteWeight(BodyWeightEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apagar pesagem?'),
        content: Text(
          '${_formatKg(entry.weightKg)} em ${_dateFormat.format(entry.date)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (confirmed != true || entry.id == null) return;
    await _service.deleteWeight(widget.uid, entry.id!);
  }

  String _formatKg(double kg) =>
      '${kg.toStringAsFixed(kg % 1 == 0 ? 0 : 1).replaceAll('.', ',')} kg';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Dados', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.cake_outlined),
                  title: const Text('Data de nascimento'),
                  subtitle: Text(
                    _birthDate == null
                        ? 'Não informada'
                        : '${_dateFormat.format(_birthDate!)} '
                            '(${ageOn(_birthDate!, DateTime.now())} anos)',
                  ),
                  onTap: _pickBirthDate,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _heightController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Altura (m)',
                    hintText: '1,77',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _sex,
                  decoration: const InputDecoration(
                    labelText: 'Sexo',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final e in BodyProfile.sexes.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (value) => setState(() => _sex = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _goal,
                  decoration: const InputDecoration(
                    labelText: 'Objetivo',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final e in BodyProfile.goals.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (value) => setState(() => _goal = value),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: const Text('Salvar dados'),
                ),
                const Divider(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Peso',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Registrar pesagem'),
                      onPressed: _addWeight,
                    ),
                  ],
                ),
                StreamBuilder<List<BodyWeightEntry>>(
                  stream: _service.watchWeights(widget.uid),
                  builder: (context, snapshot) {
                    final weights = snapshot.data ?? const [];
                    if (weights.isEmpty) {
                      return const Text('Nenhuma pesagem registrada.');
                    }
                    final bmi = bodyMassIndex(
                      weights.first.weightKg,
                      parseDecimal(_heightController.text),
                    );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (bmi != null)
                          Text(
                            'IMC: ${bmi.toStringAsFixed(1).replaceAll('.', ',')}',
                          ),
                        for (final entry in weights)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(_formatKg(entry.weightKg)),
                            subtitle: Text(_dateFormat.format(entry.date)),
                            trailing: IconButton(
                              tooltip: 'Apagar pesagem',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _deleteWeight(entry),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
    );
  }
}
