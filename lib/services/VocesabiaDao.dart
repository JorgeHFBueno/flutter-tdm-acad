import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/vocesabia.dart';

class VocesabiaDao{
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> add(Vocesabia vocesabia) async{
    try{
      await _firestore.collection('vocesabia').add(vocesabia.toMap());
    }catch(e){
      print('Erro ao adicionar $e');
    }
  }

  Future<void> update(Vocesabia vocesabia) async{
    try{
      final snapshot  = _firestore.collection('vocesabia').doc(vocesabia.id);
      await snapshot.update(vocesabia.toMap());
    }catch(e){
      print('Erro ao alterar $e');
    }
  }

  Future<void> delete(String id) async{
    try{
      final snapshot  = _firestore.collection('vocesabia').doc(id);
      await snapshot.delete();
    }catch(e){
      print('Erro ao excluir $e');
    }
  }

  Future<List<Vocesabia>> getList() async{
    try{
      final snapshot  = await _firestore.collection('vocesabia').get();
      final lista = <Vocesabia>[];
      for(var doc in snapshot.docs){
        lista.add(Vocesabia.fromMap(doc.data(), doc.id));
      }
      return lista;
    }catch(e){
      print('Erro ao buscar dados $e');
      return [];
    }
  }
}