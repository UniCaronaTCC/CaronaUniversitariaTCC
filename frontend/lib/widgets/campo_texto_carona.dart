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
  final bool visualAtualizado;
  final String? hint;

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
    this.visualAtualizado = false,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final campo = TextField(
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
        labelText: visualAtualizado || usarLabelComoHint ? null : label,
        hintText: hint ?? (usarLabelComoHint ? label : null),
        hintStyle: visualAtualizado
            ? const TextStyle(color: Color(0xFF646B7B))
            : null,
        prefixIcon: Icon(
          icone,
          color: visualAtualizado ? const Color(0xFF646B7B) : AppColors.primary,
          size: visualAtualizado ? 20 : null,
        ),
        prefixIconConstraints: visualAtualizado
            ? const BoxConstraints(minWidth: 40, minHeight: 48)
            : null,
        suffixIcon: suffixIcon,
        suffixIconConstraints: visualAtualizado
            ? const BoxConstraints(minWidth: 32, minHeight: 48)
            : null,
        filled: true,
        fillColor: visualAtualizado ? const Color(0xFFF6F6F9) : Colors.white,
        contentPadding: visualAtualizado
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 16)
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(visualAtualizado ? 8 : 16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: visualAtualizado
            ? OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFDADCE5)),
              )
            : null,
        focusedBorder: visualAtualizado
            ? OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              )
            : null,
      ),
    );
    if (!visualAtualizado) return campo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF151824),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Semantics(label: label, child: campo),
      ],
    );
  }
}
