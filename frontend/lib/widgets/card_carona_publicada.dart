import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../models/carona.dart';
import '../utils/formatador_data.dart';
import 'visual_buscaeu.dart';

class CardCaronaPublicada extends StatelessWidget {
  final Carona carona;
  final VoidCallback onTap;
  const CardCaronaPublicada({
    super.key,
    required this.carona,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (status, cor) = switch (carona.status) {
      'ATIVA' => ('Ativa', const Color(0xFF16764B)),
      'LOTADA' => ('Lotada', const Color(0xFF9A6100)),
      'EM_ANDAMENTO' => ('Em andamento', AppColors.primary),
      'FINALIZADA' => ('Finalizada', VisualBuscaEu.secundario),
      'CANCELADA' => ('Cancelada', VisualBuscaEu.secundario),
      'EXPIRADA' => ('Expirada', VisualBuscaEu.secundario),
      _ => (carona.status, VisualBuscaEu.secundario),
    };
    final dias = carona.idRecorrencia != null
        ? carona.diasRecorrencia
        : carona.recorrente
        ? carona.diasSemana
        : <String>[];
    return Material(
      key: ValueKey('card-carona-${carona.id}'),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: VisualBuscaEu.borda),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: SeloBuscaEu(texto: status, cor: cor),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    carona.horarioFormatado,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    FormatadorData.completa(carona.dataInicio),
                    style: VisualBuscaEu.descricao,
                  ),
                ],
              ),
              Text(
                carona.rotuloHorario,
                style: const TextStyle(
                  fontSize: 12,
                  color: VisualBuscaEu.secundario,
                ),
              ),
              const SizedBox(height: 16),
              _local(carona.resumoInicio, true),
              _local(carona.destino, false),
              const Divider(height: 24),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 16,
                runSpacing: 10,
                children: [
                  _informacao(
                    Icons.people_outline,
                    '${carona.vagas} ${carona.vagas == 1 ? 'vaga' : 'vagas'}',
                  ),
                  _informacao(Icons.sell_outlined, carona.valorFormatado),
                ],
              ),
              if (dias.isNotEmpty) ...[
                const SizedBox(height: 12),
                _informacao(
                  Icons.repeat,
                  'Recorrência: ${dias.join(', ').toLowerCase()}',
                ),
              ],
              const Divider(height: 24),
              const Row(
                children: [
                  Expanded(
                    child: Text('Ver detalhes', style: VisualBuscaEu.descricao),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: VisualBuscaEu.secundario,
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _informacao(IconData icone, String texto) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icone, size: 18, color: VisualBuscaEu.secundario),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          texto,
          style: const TextStyle(
            fontSize: 14,
            color: VisualBuscaEu.texto,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ],
  );

  Widget _local(String texto, bool inicio) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 18,
          child: Column(
            children: [
              const SizedBox(height: 5),
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: inicio ? AppColors.primary : const Color(0xFFA6A9B8),
                ),
              ),
              if (inicio)
                Expanded(
                  child: Container(
                    width: 1,
                    margin: const EdgeInsets.only(top: 3),
                    color: VisualBuscaEu.borda,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              texto,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: VisualBuscaEu.texto,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
