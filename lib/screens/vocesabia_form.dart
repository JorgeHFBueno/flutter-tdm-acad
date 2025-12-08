import 'package:flutter/material.dart';
import '../components/editor.dart';
import '../services/vocesabiaDao.dart';
import '../models/vocesabia.dart';
import 'package:intl/intl.dart';

class VoceSabiaForm extends StatefulWidget{
  final Vocesabia? vocesabia; //pode vir como nulo qdo inclusão

  VoceSabiaForm({this.vocesabia});
  @override
  VoceSabiaFormState createState() => VoceSabiaFormState();
}

class VoceSabiaFormState extends State<VoceSabiaForm> {
  final TextEditingController _controladorTitulo = TextEditingController();
  final TextEditingController _controladorDescricao = TextEditingController();
  String? id;
  VocesabiaDao _service = VocesabiaDao();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("Você Sabia?"),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: (){
            gravar(context);
          },
          child: Icon(Icons.save),
        ),
        body: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              Editor(_controladorTitulo, "Título", "Informe o título", null),
              Padding(padding: EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _controladorDescricao,
                    style: TextStyle(fontSize: 20.0),
                    keyboardType: TextInputType.multiline,
                    maxLines: 10,
                    decoration: InputDecoration(
                        labelText: "Descrição",
                        hintText: "Informe a descrição"
                    ),
                  )),
            ],
          ),
        ));
  }

  void gravar(BuildContext context) async{
    if (id != null){ // alteração
      final item = Vocesabia(id: id!,
          titulo: _controladorTitulo.text,
          descricao: _controladorDescricao.text,
          timestamp: DateTime.now());
      await _service.update(item).then((value) => Navigator.pop(context));
    }else{ // inclusão
      final item = Vocesabia(id: "",
          titulo: _controladorTitulo.text,
          descricao: _controladorDescricao.text,
          timestamp: DateTime.now());
      await _service.add(item).then((value) => Navigator.pop(context));
    }
    final SnackBar snackBar =
    SnackBar(content: Text("Operação realizada com sucesso"));
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  @override
  void initState(){
    super.initState();
    if (widget.vocesabia != null){ // alteração
      id = widget.vocesabia!.id;
      _controladorTitulo.text = widget.vocesabia!.titulo;
      _controladorDescricao.text = widget.vocesabia!.descricao;
    }
  }
}
