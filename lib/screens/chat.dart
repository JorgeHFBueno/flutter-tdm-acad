import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/user.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;

class ChatScreen extends StatefulWidget{
  @override
  State<StatefulWidget> createState() {
    return ChatScreenState();
  }
}
class ChatScreenState extends State<ChatScreen>{
  TextEditingController _textController = TextEditingController();
  bool _isComposing = false;
  User? _currentUser;
  bool _isLoading = false; // para mostrar que está processando
  final picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    FirebaseAuth.instance.authStateChanges().listen((user){
      // fica ouvindo qualquer alteração de autenticação
      setState(() {
        _currentUser = user;
      });
    });
  }


  @override
  Widget build(BuildContext context) {
    CollectionReference _mensagens = FirebaseFirestore.instance.collection('mensagens');

    return Scaffold(
      appBar: AppBar( title: Text(_currentUser != null ?
      'Olá, ${_currentUser?.email}' : 'Chat'),
        actions: <Widget>[
          _currentUser != null?
          IconButton(onPressed: (){
            FirebaseAuth.instance.signOut();
          }, icon: Icon(Icons.exit_to_app))
              : Container()
        ],),
      body: Column(
          children: <Widget>[
            Expanded(child: StreamBuilder<QuerySnapshot>(
              stream: _mensagens.orderBy('time').snapshots(),
              builder: (context, snapshot){
                switch (snapshot.connectionState){
                  case ConnectionState.waiting:
                    return Center(child: CircularProgressIndicator());
                  default :
                    List<DocumentSnapshot> documents =
                    snapshot.data!.docs.reversed.toList();
                    return ListView.builder(
                      itemCount: documents.length,
                      reverse:  true, // mostra de baixo para cima
                      itemBuilder: (contex, index){
                        return displayMsg(context, documents[index], documents[index].get('uid')== _currentUser?.uid);
                        //return Text('text');
                      },
                    );
                }
              },
            )
            ),
            _isLoading ? LinearProgressIndicator() : Container(),
            composer()
          ]
      ),
    );
  }

  Widget composer() {
    return IconTheme(
        data: IconThemeData(color: Colors.cyan),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: <Widget>[
              Container(
                child: IconButton(
                  icon: Icon(Icons.photo_camera),
                  onPressed: () async {
                    final img =
                    await picker.pickImage(source: ImageSource.camera);
                    if (img == null) return;
                      _sendMessage(imgFile: img);
                  },
                ),
              ),
              Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration:
                    InputDecoration.collapsed(hintText: "Enviar uma mensagem"),
                    onChanged: (text) {
                      setState(() {
                        _isComposing = text.length > 0;
                      });
                    },
                    onSubmitted: (text) {
                      _sendMessage(text : text);
                      _reset();
                    },
                  )),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 4.0),
                child: IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _isComposing
                      ? () {
                         _sendMessage(text : _textController.text);
                    _reset();
                  }
                      : null,
                ),
              )
            ],
          ),
        ));
  }

  void _reset(){
    _textController.clear();
    setState(() {
      _isComposing = false;
    });
  }

  void _sendMessage({String? text, XFile? imgFile}) async {
    CollectionReference _mensagens = FirebaseFirestore.instance.collection('mensagens');
    // referência para subcoleção mensagens do usuário logado
    print("USER: ");
    print(_currentUser!.email);
    if (_currentUser != null){
      // se tem user logado -> grava mensagem
      setState(() {
        _isLoading = true;
      });
      Map<String, dynamic> data = {
        'time' : Timestamp.now(),
        'url'  : '',
        'text' : '',
        'uid'  : _currentUser!.uid,
        'senderName' : _currentUser!.email,
        'senderPhotoUrl' : ''
      };

      if (imgFile != null){
        //data['url'] = await _upload(imgFile);
      }else{
        data['text'] = text;
      }
      _mensagens.add(data);
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget displayMsg(BuildContext context,
      DocumentSnapshot<Object?> data, bool mine){
    return Container(
      margin: EdgeInsets.symmetric(
          vertical: 10, horizontal: 10),
      child: Row(
        children: <Widget>[
          ///primeira coluna
          !mine  ?
          Padding(padding: EdgeInsets.only(right: 16),
            child: CircleAvatar(
              backgroundImage:
              Image.network(data.get('senderPhotoUrl')).image,
            ),)
              : Container(),
          ///segunda coluna
          Expanded(
              child: Column(
                crossAxisAlignment: mine ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: <Widget>[
                  data.get('url') != ""
                      ?  Image.network(data.get("url"), width: 150)
                      : Text(
                    data.get('text'),
                    style: TextStyle(fontSize: 16),
                  ),
                  Text(data.get("senderName"),
                    style:  TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500
                    ),)
                ],
              )),
          ///terceira coluna
          mine  ?
          Padding(padding: EdgeInsets.only(right: 16),
            child: CircleAvatar(
              backgroundImage:
              Image.network(data.get('senderPhotoUrl')).image,
            ),)
              : Container(),
        ],
      ),
    );
  }

  Future<String> _upload(XFile imgFile) async {
    String imageUrl = "";
    try {
      if (imgFile != null) {
        File file = File(imgFile.path);
        firebase_storage.UploadTask uploadTask;
        firebase_storage.Reference ref = firebase_storage
            .FirebaseStorage.instance
            .ref()
            .child("imgs")
            .child(DateTime.now().millisecondsSinceEpoch.toString());
        final metadados = firebase_storage.SettableMetadata(
            contentType: "image/jpeg",
            customMetadata: {"picked-file-path": imgFile.path});
        if (kIsWeb) {
          // se estiver na plataforma WEB
          uploadTask = ref.putData(await imgFile.readAsBytes(), metadados);
        } else {
          // se for outra plataforma
          uploadTask = ref.putFile(File(imgFile.path), metadados);
        }
        var taskSnapshot = await uploadTask;
        imageUrl =
        await taskSnapshot.ref.getDownloadURL(); //URL da imagem no storage
      }
    } catch (error) {
      print(error.toString());
      print('Erro ao fazer upload da imagem: $error');
    }
    return imageUrl;
  }

}