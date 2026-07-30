import 'package:flutter/material.dart';

class Editor extends StatelessWidget {
  final TextEditingController controlador;
  final String rotulo;
  final String dica;
  final IconData? icone; // icone pode conter valor nulo
  const Editor(
    this.controlador,
    this.rotulo,
    this.dica, {
    this.icone,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.all(16.0),
        child: TextField(
          controller: controlador,
          style: const TextStyle(fontSize: 20.0),
          decoration: InputDecoration(
              icon: icone != null ? Icon(icone) : null,
              labelText: rotulo,
              hintText: dica),
        ));
  }
}
