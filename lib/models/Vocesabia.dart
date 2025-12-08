class Vocesabia{
  String id;
  String titulo;
  String descricao;
  DateTime timestamp;

  Vocesabia({
    required this.id,
    required this.titulo,
    required this.descricao,
    required this.timestamp
  });

  Map<String, dynamic> toMap() {
    //converte objeto para map
    return {
      'titulo': titulo,
      'descricao': descricao,
      'timestamp': timestamp.toIso8601String()
    };
  }

  factory Vocesabia.fromMap(Map<String, dynamic> map, String id){
    return Vocesabia(id: id as String,
        titulo: map['titulo'] as String,
        descricao: map['descricao'] as String,
        timestamp: DateTime.parse(map['timestamp'] as String));
  }
}