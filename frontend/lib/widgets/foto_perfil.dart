import 'package:flutter/material.dart';

import '../config/app_colors.dart';

class FotoPerfil extends StatelessWidget {
  final String nome;
  final String? urlFoto;
  final bool carregando;
  final VoidCallback? onTap;

  const FotoPerfil({
    super.key,
    required this.nome,
    required this.urlFoto,
    required this.carregando,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final inicial = nome.trim().isNotEmpty ? nome.trim()[0].toUpperCase() : 'U';
    final possuiFoto = urlFoto != null && urlFoto!.trim().isNotEmpty;

    return Tooltip(
      message: 'Alterar foto de perfil',
      child: InkWell(
        onTap: carregando ? null : onTap,
        customBorder: const CircleBorder(),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 42,
              backgroundColor: const Color(0xFFECDDF5),
              foregroundImage: possuiFoto ? NetworkImage(urlFoto!) : null,
              onForegroundImageError: possuiFoto ? (_, _) {} : null,
              child: carregando
                  ? const SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Text(
                      inicial,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.photo_library_outlined,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
