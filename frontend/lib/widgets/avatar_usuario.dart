import 'package:flutter/material.dart';

import '../config/app_colors.dart';

class AvatarUsuario extends StatelessWidget {
  final String nome;
  final String? urlFoto;
  final double raio;
  final bool desativado;

  const AvatarUsuario({
    super.key,
    required this.nome,
    required this.urlFoto,
    this.raio = 24,
    this.desativado = false,
  });

  @override
  Widget build(BuildContext context) {
    final texto = nome.trim();
    final inicial = texto.isEmpty ? '?' : texto[0].toUpperCase();
    final foto = urlFoto?.trim();
    final possuiFoto = foto != null && foto.isNotEmpty;

    return CircleAvatar(
      radius: raio,
      backgroundColor: desativado ? Colors.black12 : const Color(0xFFF0DEFA),
      foregroundImage: possuiFoto ? NetworkImage(foto) : null,
      onForegroundImageError: possuiFoto ? (_, _) {} : null,
      child: Text(
        inicial,
        style: TextStyle(
          color: desativado ? Colors.black54 : AppColors.primary,
          fontSize: raio * 0.75,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
