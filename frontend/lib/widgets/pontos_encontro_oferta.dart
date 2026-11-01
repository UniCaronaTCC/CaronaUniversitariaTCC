import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../models/ponto_embarque.dart';
import 'visual_buscaeu.dart';

class PontosEncontroOferta extends StatelessWidget {
  final List<PontoEmbarque> pontos;
  final bool editaveis;
  final bool edicaoLimitada;
  final VoidCallback onAdicionar;
  final ValueChanged<int> onRemover;
  const PontosEncontroOferta({
    super.key,
    required this.pontos,
    required this.editaveis,
    required this.edicaoLimitada,
    required this.onAdicionar,
    required this.onRemover,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('Pontos de encontro', style: VisualBuscaEu.titulo),
      const SizedBox(height: 6),
      Text(
        edicaoLimitada
            ? 'Locais de embarque confirmados.'
            : 'Adicione os locais onde os passageiros poderão embarcar.',
        style: VisualBuscaEu.descricao,
      ),
      const SizedBox(height: 12),
      if (pontos.isEmpty)
        const CartaoBuscaEu(
          cor: VisualBuscaEu.suave,
          child: Row(
            children: [
              Icon(
                Icons.location_off_outlined,
                color: VisualBuscaEu.secundario,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Nenhum ponto de encontro adicionado.',
                  style: VisualBuscaEu.descricao,
                ),
              ),
            ],
          ),
        )
      else
        ...List.generate(pontos.length, (indice) {
          final ponto = pontos[indice];
          final nome = ponto.nome?.trim();
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: CartaoBuscaEu(
              padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    child: Text(
                      '${indice + 1}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nome != null && nome.isNotEmpty
                              ? nome
                              : 'Ponto de encontro ${indice + 1}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: VisualBuscaEu.texto,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(ponto.endereco, style: VisualBuscaEu.descricao),
                      ],
                    ),
                  ),
                  if (editaveis && !edicaoLimitada)
                    IconButton(
                      tooltip: 'Remover ponto',
                      onPressed: () => onRemover(indice),
                      icon: const Icon(
                        Icons.close,
                        color: VisualBuscaEu.secundario,
                        size: 20,
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: editaveis && !edicaoLimitada ? onAdicionar : null,
        icon: const Icon(Icons.add, size: 20),
        label: const Text(
          'ADICIONAR PONTO DE ENCONTRO',
          textAlign: TextAlign.center,
        ),
      ),
      if (!editaveis) ...[
        const SizedBox(height: 8),
        Text(
          edicaoLimitada
              ? 'Pontos mantidos para os passageiros confirmados.'
              : 'A edição dos pontos de embarque será adicionada depois.',
          style: VisualBuscaEu.descricao,
        ),
      ],
    ],
  );
}
