import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../models/machine_catalog_item.dart';
import '../models/machine_catalog_view.dart';
import '../models/machine_configuration.dart';
import '../models/machine_history.dart';
import '../services/machine_catalog_service.dart';
import '../services/machine_history_service.dart';
import 'machine_history_screen.dart';

class MachinesScreen extends StatefulWidget {
  const MachinesScreen({
    super.key,
    this.embedInScaffold = true,
    MachineService? service,
    this.catalogService,
  }) : service = service ?? const MachineService();

  final bool embedInScaffold;
  final MachineService service;
  final MachineCatalogService? catalogService;

  @override
  State<MachinesScreen> createState() => _MachinesScreenState();
}

class _MachinesScreenState extends State<MachinesScreen> {
  late final MachineCatalogService _catalogService;
  final _search = TextEditingController();
  MachineCatalogSort _sort = MachineCatalogSort.popularName;
  MachineCatalogStatus _status = MachineCatalogStatus.all;
  String? _category;
  Future<MachineCatalogImportReport>? _import;

  @override
  void initState() {
    super.initState();
    _catalogService = widget.catalogService ?? MachineCatalogService();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) _import = _catalogService.importLocalCatalogOnce(uid);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final content = user == null
        ? const Center(child: Text('Usuário não autenticado.'))
        : FutureBuilder<MachineCatalogImportReport>(
            future: _import,
            builder: (context, importSnapshot) {
              if (importSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (importSnapshot.hasError) {
                return _error('Erro ao importar o catálogo.', () {
                  setState(() =>
                      _import = _catalogService.importLocalCatalog(user.uid));
                });
              }
              return StreamBuilder<List<MachineCatalogItem>>(
                stream: _catalogService.watchCatalog(),
                builder: (context, catalogSnapshot) {
                  if (catalogSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (catalogSnapshot.hasError) {
                    return _error(
                        'Erro ao carregar o catálogo.', () => setState(() {}));
                  }
                  return StreamBuilder<List<MachineProfile>>(
                    stream: widget.service.watchForUser(user.uid),
                    builder: (context, profileSnapshot) {
                      if (profileSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (profileSnapshot.hasError) {
                        return _error('Erro ao carregar perfis pessoais.',
                            () => setState(() {}));
                      }
                      return _list(user.uid, catalogSnapshot.data ?? const [],
                          profileSnapshot.data ?? const []);
                    },
                  );
                },
              );
            },
          );
    if (!widget.embedInScaffold) return content;
    return Scaffold(
        appBar: AppBar(title: const Text('Máquinas')), body: content);
  }

  Widget _error(String message, VoidCallback retry) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(message),
          TextButton(onPressed: retry, child: const Text('Tentar novamente')),
        ]),
      );

  Widget _list(String uid, List<MachineCatalogItem> catalog,
      List<MachineProfile> profiles) {
    final visible = filterAndSortMachineCatalog(
      combineMachineCatalog(catalog, profiles),
      query: _search.text,
      category: _category,
      status: _status,
      sort: _sort,
    );
    final pendingCount = catalog.where((item) => item.isPendingReview).length;
    return ListView(padding: const EdgeInsets.all(16), children: [
      // Full catalog editing lives on the web; the APK only quick-adds.
      if (kIsWeb)
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: () => _editCatalog(uid),
            icon: const Icon(Icons.add),
            label: const Text('Adicionar ao catálogo'),
          ),
        ),
      if (pendingCount > 0)
        Card(
          child: ListTile(
            leading: const Icon(Icons.rate_review_outlined),
            title: Text('$pendingCount pendente(s) de revisão'),
            subtitle: Text(kIsWeb
                ? 'Toque para filtrar e complete pelo menu Editar catálogo.'
                : 'Revise pela versão web.'),
            onTap: () => setState(() => _status = MachineCatalogStatus.pending),
          ),
        ),
      const SizedBox(height: 8),
      TextField(
        controller: _search,
        decoration: InputDecoration(
          labelText: 'Pesquisar por nome popular ou científico',
          border: const OutlineInputBorder(),
          suffixIcon: _search.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Limpar',
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _search.clear();
                    setState(() {});
                  },
                ),
        ),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 8),
      Wrap(
          spacing: 12,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DropdownButton<String?>(
              value: _category,
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('Todas as categorias')),
                for (final value in MachineCatalogCategory.values)
                  DropdownMenuItem(
                      value: value,
                      child: Text(MachineCatalogCategory.label(value))),
              ],
              onChanged: (value) => setState(() => _category = value),
            ),
            DropdownButton<MachineCatalogStatus>(
              value: _status,
              items: const [
                DropdownMenuItem(
                    value: MachineCatalogStatus.all, child: Text('Todas')),
                DropdownMenuItem(
                    value: MachineCatalogStatus.active, child: Text('Ativas')),
                DropdownMenuItem(
                    value: MachineCatalogStatus.retired,
                    child: Text('Aposentadas')),
                DropdownMenuItem(
                    value: MachineCatalogStatus.pending,
                    child: Text('Pendentes')),
              ],
              onChanged: (value) => setState(() => _status = value!),
            ),
            SegmentedButton<MachineCatalogSort>(
              segments: const [
                ButtonSegment(
                    value: MachineCatalogSort.popularName,
                    label: Text('Nome popular')),
                ButtonSegment(
                    value: MachineCatalogSort.scientificName,
                    label: Text('Nome científico')),
              ],
              selected: {_sort},
              onSelectionChanged: (value) =>
                  setState(() => _sort = value.single),
            ),
          ]),
      if (catalog.isEmpty)
        const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('Catálogo vazio.')))
      else if (visible.isEmpty)
        const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('Nenhum resultado encontrado.'))),
      for (final item in visible)
        _CatalogCard(
          item: item,
          onTap: () => _openItem(uid, item),
          onAction: (action) => _action(uid, item.catalog, action),
        ),
    ]);
  }

  Future<void> _openItem(String uid, ResolvedMachineCatalogItem item) async {
    if (item.profile != null) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => MachineDetailScreen(
          ownerUid: uid,
          exerciseId: item.catalog.id,
          catalogItem: item.catalog,
        ),
      ));
      return;
    }
    if (item.catalog.isRetired) {
      _message('Máquina aposentada não pode ser cadastrada.');
      return;
    }
    final result =
        await showMachineConfigurationDialog(context, requireComplete: true);
    if (result == null || !mounted) return;
    try {
      await widget.service.ensureMachine(
        ownerUid: uid,
        exerciseId: item.catalog.id,
        exerciseName: item.catalog.popularName,
        category: item.catalog.category,
        observation: result.observation,
        currentSets: result.currentSets,
        currentRepetitions: result.currentRepetitions,
        currentWeightKg: result.currentWeightKg,
      );
      if (mounted) _message('Máquina cadastrada.');
    } catch (_) {
      if (mounted) _message('Erro ao cadastrar Máquina.');
    }
  }

  Future<void> _editCatalog(String uid, [MachineCatalogItem? item]) =>
      showDialog<void>(
        context: context,
        builder: (_) => _CatalogEditor(
          service: _catalogService,
          uid: uid,
          item: item,
        ),
      );

  Future<void> _action(
      String uid, MachineCatalogItem item, String action) async {
    if (action == 'edit') {
      await _editCatalog(uid, item);
      return;
    }
    final retire = action == 'retire';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(retire ? 'Aposentar Máquina' : 'Reativar Máquina'),
        content: Text(retire
            ? 'A Máquina não poderá ser cadastrada por novos usuários nem adicionada a novos Treinos. Perfis, Treinos, Sessões e históricos existentes serão preservados.'
            : 'A Máquina voltará a ficar disponível para cadastro e inclusão em Treinos.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(retire ? 'Aposentar' : 'Reativar')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      if (retire) {
        await _catalogService.retire(item.id, uid);
      } else {
        await _catalogService.reactivate(item.id, uid);
      }
    } catch (_) {
      if (mounted) _message('Não foi possível concluir a operação.');
    }
  }

  void _message(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));
}

class _CatalogCard extends StatelessWidget {
  const _CatalogCard(
      {required this.item, required this.onTap, required this.onAction});
  final ResolvedMachineCatalogItem item;
  final VoidCallback onTap;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final profile = item.profile;
    final config = resolveExerciseConfiguration(machine: profile);
    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text(item.popularName,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.scientificName),
          Text(
              '${MachineCatalogCategory.label(item.category)} · ${MachineCatalogType.label(item.catalog.type)}'),
          Text([
            if (item.catalog.isPendingReview) 'PENDENTE',
            if (item.catalog.isRetired) 'APOSENTADA',
            item.isRegistered ? 'Cadastrada' : 'Não cadastrada',
          ].join(' · ')),
          if (profile != null)
            Text(
                '${config.compactLabel} · contador ${profile.completionCount}'),
          if ((profile?.observationText.trim() ?? '').isNotEmpty)
            Text('OBS: ${profile!.observationText.trim()}',
                maxLines: 2, overflow: TextOverflow.ellipsis),
        ]),
        trailing: PopupMenuButton<String>(
          onSelected: onAction,
          itemBuilder: (_) => [
            if (kIsWeb)
              const PopupMenuItem(
                  value: 'edit', child: Text('Editar catálogo')),
            PopupMenuItem(
              value: item.catalog.isRetired ? 'reactivate' : 'retire',
              child: Text(item.catalog.isRetired ? 'Reativar' : 'Aposentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogEditor extends StatefulWidget {
  const _CatalogEditor({required this.service, required this.uid, this.item});
  final MachineCatalogService service;
  final String uid;
  final MachineCatalogItem? item;
  @override
  State<_CatalogEditor> createState() => _CatalogEditorState();
}

class _CatalogEditorState extends State<_CatalogEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _popular;
  late final TextEditingController _scientific;
  late String _category;
  late String _type;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _popular = TextEditingController(text: widget.item?.popularName);
    _scientific = TextEditingController(text: widget.item?.scientificName);
    _category = widget.item?.category ?? MachineCatalogCategory.outros;
    _type = widget.item?.type ?? MachineCatalogType.outro;
  }

  @override
  void dispose() {
    _popular.dispose();
    _scientific.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.item == null
            ? 'Adicionar ao catálogo'
            : 'Editar item do catálogo'),
        content: Form(
          key: _form,
          child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
                controller: _popular,
                decoration: const InputDecoration(labelText: 'Nome popular'),
                validator: validateCatalogName),
            TextFormField(
                controller: _scientific,
                decoration: const InputDecoration(labelText: 'Nome científico'),
                validator: validateCatalogName),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Categoria'),
              items: [
                for (final value in MachineCatalogCategory.values)
                  DropdownMenuItem(
                      value: value,
                      child: Text(MachineCatalogCategory.label(value)))
              ],
              onChanged: (value) => _category = value!,
            ),
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: [
                for (final value in MachineCatalogType.values)
                  DropdownMenuItem(
                      value: value,
                      child: Text(MachineCatalogType.label(value)))
              ],
              onChanged: (value) => _type = value!,
            ),
          ])),
        ),
        actions: [
          TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Salvar'),
          ),
        ],
      );

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      final item = widget.item;
      if (item == null) {
        await widget.service.add(
            uid: widget.uid,
            popularName: _popular.text,
            scientificName: _scientific.text,
            category: _category,
            type: _type);
      } else {
        await widget.service.edit(
            id: item.id,
            uid: widget.uid,
            popularName: _popular.text,
            scientificName: _scientific.text,
            category: _category,
            type: _type);
      }
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
        error is MachineCatalogDuplicateException
            ? error.message
            : 'Erro ao salvar item do catálogo.',
      )));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
