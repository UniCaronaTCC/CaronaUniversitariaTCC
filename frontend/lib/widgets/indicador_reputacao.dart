import 'package:flutter/material.dart';

import '../models/reputacao.dart';

class IndicadorReputacao extends StatelessWidget {
  final Reputacao? reputacao;

  const IndicadorReputacao({super.key, required this.reputacao});

  @override
  Widget build(BuildContext context) {
    final resumo = reputacao;
    // Ausencia do resumo nao significa que o perfil nunca foi avaliado.
    if (resumo == null) return const SizedBox.shrink();
    final avaliado = resumo.total > 0;
    final quantidade = resumo.total == 1
        ? '1 avaliação'
        : '${resumo.total} avaliações';
    final texto = avaliado
        ? '${resumo.mediaFormatada} / 5 · $quantidade'
        : 'Perfil ainda não avaliado';

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Semantics(
        label: avaliado
            ? 'Reputação: ${resumo.mediaFormatada} de 5. $quantidade.'
            : texto,
        child: ExcludeSemantics(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                avaliado ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 18,
                color: avaliado ? const Color(0xFF9A6100) : Colors.black54,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  texto,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
