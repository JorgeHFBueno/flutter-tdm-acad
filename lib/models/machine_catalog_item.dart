// ignore: depend_on_referenced_packages
import 'package:cloud_firestore/cloud_firestore.dart';

const int machineCatalogSchemaVersion = 1;
const String machineCatalogOriginLocalSeed = 'local_seed';
const String machineCatalogOriginManual = 'manual';
const String machineCatalogOriginQuickAdd = 'criacao_rapida';

class MachineCatalogItem {
  final String id;
  final String popularName;
  final String scientificName;
  final String category;
  final String type;
  final String createdByUid;
  final bool isRetired;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? updatedByUid;
  final DateTime? retiredAt;
  final String? retiredByUid;
  final int schemaVersion;
  final String origin;
  final bool scientificNamePending;

  const MachineCatalogItem({
    required this.id,
    required this.popularName,
    required this.scientificName,
    required this.category,
    required this.type,
    required this.createdByUid,
    this.isRetired = false,
    this.createdAt,
    this.updatedAt,
    this.updatedByUid,
    this.retiredAt,
    this.retiredByUid,
    this.schemaVersion = machineCatalogSchemaVersion,
    this.origin = machineCatalogOriginManual,
    this.scientificNamePending = false,
  });

  factory MachineCatalogItem.fromMap(
    Map<String, dynamic> map, {
    required String id,
  }) {
    return MachineCatalogItem(
      id: id,
      popularName: _string(map['nome_popular']),
      scientificName: _string(map['nome_cientifico']),
      category: _string(map['categoria']),
      type: _string(map['tipo']),
      createdByUid: _string(map['criado_por']),
      isRetired: _bool(map['aposentada']),
      createdAt: _date(map['criado_em']),
      updatedAt: _date(map['atualizado_em']),
      updatedByUid: _optionalString(map['atualizado_por']),
      retiredAt: _date(map['aposentado_em']),
      retiredByUid: _optionalString(map['aposentado_por']),
      schemaVersion: _int(map['schema_version'], 1),
      origin: _string(map['origem']),
      scientificNamePending: _bool(map['nome_cientifico_pendente']),
    );
  }

  Map<String, dynamic> toMap() => {
        'nome_popular': popularName,
        'nome_cientifico': scientificName,
        'categoria': category,
        'criado_por': createdByUid,
        'tipo': type,
        'aposentada': isRetired,
        if (createdAt != null) 'criado_em': Timestamp.fromDate(createdAt!),
        if (updatedAt != null) 'atualizado_em': Timestamp.fromDate(updatedAt!),
        if (updatedByUid != null) 'atualizado_por': updatedByUid,
        if (retiredAt != null) 'aposentado_em': Timestamp.fromDate(retiredAt!),
        if (retiredByUid != null) 'aposentado_por': retiredByUid,
        'schema_version': schemaVersion,
        'origem': origin,
        'nome_cientifico_pendente': scientificNamePending,
      };

  bool get isComplete =>
      id.trim().isNotEmpty &&
      popularName.trim().isNotEmpty &&
      scientificName.trim().isNotEmpty &&
      MachineCatalogCategory.values.contains(category) &&
      MachineCatalogType.values.contains(type) &&
      createdByUid.trim().isNotEmpty;
}

class MachineCatalogCategory {
  static const peito = 'peito';
  static const costas = 'costas';
  static const ombros = 'ombros';
  static const biceps = 'biceps';
  static const triceps = 'triceps';
  static const pernas = 'pernas';
  static const gluteos = 'gluteos';
  static const panturrilhas = 'panturrilhas';
  static const core = 'core';
  static const cardio = 'cardio';
  static const outros = 'outros';

  static const values = <String>[
    peito,
    costas,
    ombros,
    biceps,
    triceps,
    pernas,
    gluteos,
    panturrilhas,
    core,
    cardio,
    outros,
  ];
  static const labels = <String, String>{
    peito: 'Peito',
    costas: 'Costas',
    ombros: 'Ombros',
    biceps: 'Bíceps',
    triceps: 'Tríceps',
    pernas: 'Pernas',
    gluteos: 'Glúteos',
    panturrilhas: 'Panturrilhas',
    core: 'Core',
    cardio: 'Cardio',
    outros: 'Outros',
  };
  static String label(String value) => labels[value] ?? 'Outros';
}

class MachineCatalogType {
  static const maquina = 'maquina';
  static const halteres = 'halteres';
  static const barra = 'barra';
  static const polia = 'polia';
  static const pesoCorporal = 'peso_corporal';
  static const elastico = 'elastico';
  static const equipamentoLivre = 'equipamento_livre';
  static const outro = 'outro';

  static const values = <String>[
    maquina,
    halteres,
    barra,
    polia,
    pesoCorporal,
    elastico,
    equipamentoLivre,
    outro,
  ];
  static const labels = <String, String>{
    maquina: 'Máquina',
    halteres: 'Halteres',
    barra: 'Barra',
    polia: 'Polia',
    pesoCorporal: 'Peso corporal',
    elastico: 'Elástico',
    equipamentoLivre: 'Equipamento livre',
    outro: 'Outro',
  };
  static String label(String value) => labels[value] ?? 'Outro';
}

String _string(Object? value) =>
    value is String ? value : value?.toString() ?? '';
String? _optionalString(Object? value) {
  final result = _string(value).trim();
  return result.isEmpty ? null : result;
}

bool _bool(Object? value) =>
    value is bool ? value : value?.toString() == 'true';
int _int(Object? value, int fallback) => value is num
    ? value.toInt()
    : int.tryParse(value?.toString() ?? '') ?? fallback;
DateTime? _date(Object? value) => value is Timestamp ? value.toDate() : null;
