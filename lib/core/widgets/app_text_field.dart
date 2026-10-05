import 'package:flutter/material.dart';

/// Labelled text field with the app's input style.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.icon,
    this.suffix,
    this.keyboardType,
    this.obscure = false,
    this.validator,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final IconData? icon;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final bool obscure;
  final String? Function(String?)? validator;
  final Iterable<String>? autofillHints;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscure,
        validator: validator,
        autofillHints: autofillHints,
        textCapitalization: textCapitalization,
        onFieldSubmitted: onSubmitted,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon == null ? null : Icon(icon),
          suffixIcon: suffix,
        ),
      );
}
