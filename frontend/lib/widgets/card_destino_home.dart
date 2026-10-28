import 'package:flutter/material.dart';

import '../config/app_colors.dart';

class CardDestinoHome extends StatelessWidget {
  final String destino;
  final String? nome;
  final String? endereco;
  final VoidCallback onTap;

  const CardDestinoHome({
    super.key,
    required this.destino,
    this.nome,
    this.endereco,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final nomeLimpo = nome?.trim() ?? '';
    final enderecoLimpo = endereco?.trim() ?? '';
    final titulo = nomeLimpo.isEmpty ? destino.trim() : nomeLimpo;
    final mostrarEndereco =
        enderecoLimpo.isNotEmpty &&
        enderecoLimpo.toLowerCase() != titulo.toLowerCase();

    return Material(
      color: const Color(0xFFF5F5F8),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  color: AppColors.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Seu destino',
                        style: TextStyle(color: Colors.black54, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        titulo,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (mostrarEndereco) ...[
                        const SizedBox(height: 4),
                        Text(
                          enderecoLimpo,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: Colors.black54),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
