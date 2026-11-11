import 'package:flutter/material.dart';

class MyTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final Widget icon;
  final bool obscureText;
  final bool capitalization;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;

  const MyTextField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.icon,
    required this.obscureText,
    required this.capitalization,
    this.keyboardType,
    this.autofillHints,
  });

  @override
  State<MyTextField> createState() {
    return MyTextFieldState();
  }
}

class MyTextFieldState extends State<MyTextField> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: TextFormField(
        keyboardType: widget.keyboardType,
        autofillHints: widget.autofillHints,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Preenchimento obrigatorio!';
          }
          return null;
        },
        onFieldSubmitted: (value) {
          setState(() {
            widget.controller.text = value;
          });
        },
        textCapitalization: widget.capitalization
            ? TextCapitalization.words
            : TextCapitalization.none,
        controller: widget.controller,
        obscureText: widget.obscureText,
        decoration: InputDecoration(
          filled: true,
          hintText: widget.hintText,
          labelText: widget.hintText,
          prefixIconColor: theme.colorScheme.primary,
          prefixIcon: Padding(
            padding: const EdgeInsets.all(0),
            child: widget.icon,
          ),
        ),
      ),
    );
  }
}
