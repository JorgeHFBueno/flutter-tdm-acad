import 'dart:async';

// ignore: depend_on_referenced_packages
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../data/machine_catalog_seed.dart';
import '../models/machine_catalog_item.dart';
import '../models/machine_catalog_view.dart';

const String machineCatalogCollection = 'machine_catalog';

class MachineCatalogImportReport {
  final int total;
  final List<String> createdIds;
  final List<String> skippedIds;
  final Map<String, Object> failures;

  const MachineCatalogImportReport({
    required this.total,
    required this.createdIds,
    required this.skippedIds,
    required this.failures,
  });

  int get created => createdIds.length;
  int get skipped => skippedIds.length;
  bool get hasFailures => failures.isNotEmpty;
}

class MachineCatalogDuplicateException implements Exception {
  final String message;
  const MachineCatalogDuplicateException(this.message);
  @override
  String toString() => message;
}

class MachineCatalogService {
  MachineCatalogService({FirebaseFirestore? firestore})
      : _firestoreOverride = firestore;

  final FirebaseFirestore? _firestoreOverride;
  static final Set<String> _importedForSession = <String>{};
  static final Map<String, Future<MachineCatalogImportReport>> _imports = {};

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(machineCatalogCollection);

  Stream<List<MachineCatalogItem>> watchCatalog() => _collection
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => MachineCatalogItem.fromMap(doc.data(), id: doc.id))
            .toList(growable: false),
      );

  Future<List<MachineCatalogItem>> listCatalog() async {
    final snapshot = await _collection.get();
    return snapshot.docs
        .map((doc) => MachineCatalogItem.fromMap(doc.data(), id: doc.id))
        .toList(growable: false);
  }

  Future<MachineCatalogItem?> getById(String id) async {
    final doc = await _collection.doc(id).get();
    final data = doc.data();
    return !doc.exists || data == null
        ? null
        : MachineCatalogItem.fromMap(data, id: doc.id);
  }

  Future<MachineCatalogImportReport> importLocalCatalogOnce(String uid) {
    if (_importedForSession.contains(uid)) {
      return Future.value(MachineCatalogImportReport(
        total: localMachineCatalogSeed.length,
        createdIds: const [],
        skippedIds: localMachineCatalogSeed.map((item) => item.id).toList(),
        failures: const {},
      ));
    }
    return _imports.putIfAbsent(uid, () async {
      final report = await importLocalCatalog(uid);
      if (!report.hasFailures) _importedForSession.add(uid);
      _imports.remove(uid);
      return report;
    });
  }

  Future<MachineCatalogImportReport> importLocalCatalog(String uid) async {
    final existing = await _collection.get();
    final existingIds = existing.docs.map((doc) => doc.id).toSet();
    final skipped = localMachineCatalogSeed
        .where((item) => existingIds.contains(item.id))
        .map((item) => item.id)
        .toList();
    final created = <String>[];
    final failures = <String, Object>{};
    for (final seed
        in missingMachineCatalogSeeds(localMachineCatalogSeed, existingIds)) {
      try {
        final wasCreated = await _firestore.runTransaction((transaction) async {
          final ref = _collection.doc(seed.id);
          final current = await transaction.get(ref);
          if (current.exists) return false;
          final now = FieldValue.serverTimestamp();
          transaction.set(ref, {
            'nome_popular': seed.popularName.trim(),
            'nome_cientifico': seed.scientificName.trim(),
            'categoria': seed.category,
            'criado_por': uid,
            'tipo': seed.type,
            'aposentada': false,
            'criado_em': now,
            'atualizado_em': now,
            'atualizado_por': uid,
            'schema_version': machineCatalogSchemaVersion,
            'origem': machineCatalogOriginLocalSeed,
            'nome_cientifico_pendente': seed.scientificNamePending,
          });
          return true;
        });
        (wasCreated ? created : skipped).add(seed.id);
      } catch (error) {
        failures[seed.id] = error;
      }
    }
    final report = MachineCatalogImportReport(
      total: localMachineCatalogSeed.length,
      createdIds: List.unmodifiable(created),
      skippedIds: List.unmodifiable(skipped),
      failures: Map.unmodifiable(failures),
    );
    debugPrint(
        'Machine catalog seed: total=${report.total}, created=${report.created}, '
        'skipped=${report.skipped}, failures=${report.failures.length}');
    return report;
  }

  Future<MachineCatalogItem> add({
    required String uid,
    required String popularName,
    required String scientificName,
    required String category,
    required String type,
    String origin = machineCatalogOriginManual,
    bool scientificNamePending = false,
  }) async {
    final popular = popularName.trim();
    final scientific = scientificName.trim();
    _validate(popular, scientific, category, type);
    await _ensureNoDuplicate(popular, scientific);
    final ref = _collection.doc();
    final now = FieldValue.serverTimestamp();
    await ref.set({
      'nome_popular': popular,
      'nome_cientifico': scientific,
      'categoria': category,
      'criado_por': uid,
      'tipo': type,
      'aposentada': false,
      'criado_em': now,
      'atualizado_em': now,
      'atualizado_por': uid,
      'schema_version': machineCatalogSchemaVersion,
      'origem': origin,
      'nome_cientifico_pendente': scientificNamePending,
    });
    return MachineCatalogItem(
      id: ref.id,
      popularName: popular,
      scientificName: scientific,
      category: category,
      type: type,
      createdByUid: uid,
      origin: origin,
      scientificNamePending: scientificNamePending,
    );
  }

  Future<void> edit({
    required String id,
    required String uid,
    required String popularName,
    required String scientificName,
    required String category,
    required String type,
  }) async {
    final popular = popularName.trim();
    final scientific = scientificName.trim();
    _validate(popular, scientific, category, type);
    await _ensureNoDuplicate(popular, scientific, excludingId: id);
    await _collection.doc(id).update({
      'nome_popular': popular,
      'nome_cientifico': scientific,
      'categoria': category,
      'tipo': type,
      'nome_cientifico_pendente': false,
      'atualizado_em': FieldValue.serverTimestamp(),
      'atualizado_por': uid,
    });
  }

  Future<void> retire(String id, String uid) => _collection.doc(id).update({
        'aposentada': true,
        'aposentado_em': FieldValue.serverTimestamp(),
        'aposentado_por': uid,
        'atualizado_em': FieldValue.serverTimestamp(),
        'atualizado_por': uid,
      });

  Future<void> reactivate(String id, String uid) => _collection.doc(id).update({
        'aposentada': false,
        'aposentado_em': FieldValue.delete(),
        'aposentado_por': FieldValue.delete(),
        'atualizado_em': FieldValue.serverTimestamp(),
        'atualizado_por': uid,
      });

  Future<void> _ensureNoDuplicate(String popular, String scientific,
      {String? excludingId}) async {
    final items = await listCatalog();
    final key = catalogDuplicateKey(popular, scientific);
    for (final item in items) {
      if (item.id == excludingId) continue;
      if (normalizeCatalogText(item.scientificName) ==
          normalizeCatalogText(scientific)) {
        throw const MachineCatalogDuplicateException(
          'Já existe uma Máquina com este nome científico.',
        );
      }
      if (catalogDuplicateKey(item.popularName, item.scientificName) == key) {
        throw const MachineCatalogDuplicateException(
            'Esta Máquina já existe no catálogo.');
      }
    }
  }

  void _validate(
      String popular, String scientific, String category, String type) {
    if (validateCatalogName(popular) != null ||
        validateCatalogName(scientific) != null) {
      throw const FormatException(
          'Nomes são obrigatórios e devem ter até 120 caracteres.');
    }
    if (!MachineCatalogCategory.values.contains(category) ||
        !MachineCatalogType.values.contains(type)) {
      throw const FormatException('Categoria ou tipo inválido.');
    }
  }
}
