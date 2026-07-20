import 'package:flutter/material.dart';

import '../config/app_colors.dart';

// Botao grande reutilizavel nas telas principais.
class BotaoAcaoHome extends StatelessWidget {
  final String texto;
  final IconData icone;

  // Quando for null, o botao fica desativado.
  final VoidCallback? onPressed;

  const BotaoAcaoHome({
    super.key,
    required this.texto,
    required this.icone,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 82,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icone, size: 32),
        label: Text(
          texto,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.55),
          disabledForegroundColor: Colors.white70,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: onPressed == null ? 0 : 6,
        ),
      ),
    );
  }
}
