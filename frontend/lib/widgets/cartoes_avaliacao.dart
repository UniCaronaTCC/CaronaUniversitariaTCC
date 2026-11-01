import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import 'avatar_usuario.dart';
import 'visual_buscaeu.dart';

class ResumoAvaliacoes extends StatelessWidget {
  final String nome;
  final double media;
  final int total;
  const ResumoAvaliacoes({
    super.key,
    required this.nome,
    required this.media,
    required this.total,
  });

  @override
  Widget build(BuildContext context) => CartaoBuscaEu(
    cor: AppColors.primary.withValues(alpha: .04),
    child: Row(
      children: [
        AvatarUsuario(nome: nome, urlFoto: null, raio: 30),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nome, style: VisualBuscaEu.titulo),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.star, color: Color(0xFFE7A524), size: 24),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '${media.toStringAsFixed(1).replaceAll('.', ',')} / 5',
                      style: VisualBuscaEu.titulo.copyWith(fontSize: 22),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                total == 1 ? '1 avaliação' : '$total avaliações',
                style: VisualBuscaEu.descricao,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class CardAvaliacao extends StatelessWidget {
  final String nome;
  final String? foto;
  final String data;
  final String comentario;
  final int nota;
  const CardAvaliacao({
    super.key,
    required this.nome,
    this.foto,
    required this.data,
    required this.comentario,
    required this.nota,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: CartaoBuscaEu(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AvatarUsuario(nome: nome, urlFoto: foto, raio: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          nome,
                          style: VisualBuscaEu.titulo.copyWith(fontSize: 15),
                        ),
                        if (data.isNotEmpty)
                          Text(
                            data,
                            style: VisualBuscaEu.descricao.copyWith(
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      children: List.generate(
                        5,
                        (indice) => Icon(
                          indice < nota ? Icons.star : Icons.star_border,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            comentario.isNotEmpty ? comentario : 'Sem comentário',
            style: VisualBuscaEu.descricao.copyWith(color: VisualBuscaEu.texto),
          ),
        ],
      ),
    ),
  );
}
