import 'package:flutter/material.dart';

class MyButton extends StatefulWidget {
  final Function()? onPressed;
  final GlobalKey<FormState> formKey;
  final String text;

  const MyButton({
    super.key,
    required this.onPressed,
    required this.formKey,
    required this.text,
  });

  @override
  State<MyButton> createState() {
    return MyButtonState();
  }
}

class MyButtonState extends State<MyButton> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 25),
      child: SizedBox(
        height: 55,
        width: double.maxFinite,
        child: ElevatedButton(
          onPressed: widget.onPressed == null
              ? null
              : () {
                  if (widget.formKey.currentState!.validate()) {
                    widget.onPressed!();
                  }
                },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.all(18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            widget.text,
            style: theme.textTheme.labelLarge?.copyWith(
              color: widget.onPressed == null
                  ? theme.disabledColor
                  : theme.colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}
