import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_colors.dart';

class CampoTextoCarona extends StatelessWidget {
  final String label;
  final IconData icone;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool somenteLeitura;
  final Widget? suffixIcon;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final bool usarLabelComoHint;

  const CampoTextoCarona({
    super.key,
    required this.label,
    required this.icone,
    required this.controller,
    this.keyboardType,
    this.maxLines = 1,
    this.somenteLeitura = false,
    this.suffixIcon,
    this.onTap,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.inputFormatters,
    this.usarLabelComoHint = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      readOnly: somenteLeitura,
      onTap: onTap,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      style: const TextStyle(color: AppColors.text),
      decoration: InputDecoration(
        labelText: usarLabelComoHint ? null : label,
        hintText: usarLabelComoHint ? label : null,
        prefixIcon: Icon(icone, color: AppColors.primary),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
