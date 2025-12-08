import 'package:flutter/material.dart';
import '../services/vocesabiaDao.dart';
import '../models/vocesabia.dart';
import 'package:intl/intl.dart';
import 'vocesabia_form.dart';

class VoceSabiaList extends StatefulWidget{
  @override
  VoceSabiaListState createState() => VoceSabiaListState();
}

class VoceSabiaListState extends State<VoceSabiaList>{
  List<Vocesabia> _vocesabia = [];
  final VocesabiaDao _service = VocesabiaDao();

  Future<void> _fetchVocesabia() async{
    try{
      final vocesabia = await _service.getList();
      setState(() {
        _vocesabia = vocesabia;
      });
    }catch (e){
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao carregar dados!")));
    }
  }

  @override
  void initState(){
    super.initState();
    _fetchVocesabia();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Você Sabia?")),
      floatingActionButton: FloatingActionButton(
        onPressed: (){
          final Future future = Navigator.push(context,
              MaterialPageRoute(builder: (context) {
                return VoceSabiaForm();
              }));
          future.then((item) {
            setState(() {
              _fetchVocesabia();
            });
          });
        },
        child: Icon(Icons.add),
      ),
      body: ListView.builder(
          itemCount: _vocesabia.length,
          itemBuilder: (context, index){
            final item = _vocesabia[index];
            String docId = item.id;
            return Item(context, item);
          }),
    );
  }

  Widget Item(BuildContext context, Vocesabia _vocesabia){
    return GestureDetector(
        onTap: () {
          final Future future = Navigator.push(context,
              MaterialPageRoute(builder: (context){
                return VoceSabiaForm(vocesabia : _vocesabia);
              }));
          future.then((value) =>
              setState(() {
                _fetchVocesabia();// para atualizar  a listagem
              })
          );
        },
        child: Card(
          child: ListTile(
            title: Text(_vocesabia.titulo),
            subtitle: Text('Data:'
                ' ${DateFormat('dd/MM/yyyy').format(_vocesabia.timestamp)}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                GestureDetector(
                  onTap: (){
                    _excluir(context, _vocesabia.id);
                  },
                  child: Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.remove_circle,
                          color: Colors.red )
                  ),
                )
              ],
            ),
          ),
        ));
  }

  void _excluir(BuildContext context, String id){
    showDialog(
        context: context,
        builder: (BuildContext context){
          return AlertDialog(
            title: Text("Confirmação Exclusão"),
            content: Text("Tem certeza de que deseja excluir este item?"),
            actions: <Widget>[
              TextButton(
                onPressed: (){
                  Navigator.of(context).pop();
                },
                child: Text("Cancelar"),
              ),
              TextButton(
                  onPressed: (){
                    _service.delete(id).then((value) =>
                        setState(() {
                          _fetchVocesabia();
                        }));
                    Navigator.of(context).pop();
                  },
                  child: Text("Excluir"))
            ],
          );
        }
    );
  }
}