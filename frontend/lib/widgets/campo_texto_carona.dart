import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_colors.dart';

// Campo reutilizavel nos formularios de carona.
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
  final List<TextInputFormatter>? inputFormatters;

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
    this.inputFormatters,
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
      inputFormatters: inputFormatters,
      style: const TextStyle(color: AppColors.text),
      decoration: InputDecoration(
        labelText: label,
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
