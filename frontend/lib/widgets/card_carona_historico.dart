import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../models/carona.dart';
import 'visual_buscaeu.dart';

class CardCaronaHistorico extends StatelessWidget {
  final Carona carona;
  final VoidCallback onTap;
  final VoidCallback? onAvaliarPassageiros;

  const CardCaronaHistorico({
    super.key,
    required this.carona,
    required this.onTap,
    this.onAvaliarPassageiros,
  });

  @override
  Widget build(BuildContext context) => Material(
    key: ValueKey('card-carona-${carona.id}'),
    color: carona.encerrada ? const Color(0xFFF1F1F1) : Colors.white,
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
            Wrap(
              spacing: 16,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.directions_car_outlined,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        carona.motorista,
                        style: VisualBuscaEu.titulo.copyWith(fontSize: 16),
                      ),
                    ),
                  ],
                ),
                Text(
                  carona.valorFormatado,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              carona.rotuloHorario,
              style: VisualBuscaEu.descricao.copyWith(fontSize: 12),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  carona.horarioFormatado,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  carona.recorrente && carona.diasSemana.isNotEmpty
                      ? carona.diasSemana.join(', ')
                      : carona.dataFormatada,
                  style: VisualBuscaEu.descricao,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Destino', style: VisualBuscaEu.descricao),
            const SizedBox(height: 6),
            _local(Icons.location_on_outlined, carona.destino, destaque: true),
            const SizedBox(height: 10),
            _local(Icons.person_pin_circle_outlined, carona.resumoInicio),
            const Divider(height: 26),
            Row(
              children: [
                const Icon(
                  Icons.people_outline,
                  color: VisualBuscaEu.secundario,
                  size: 19,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${carona.vagas} ${carona.vagas == 1 ? 'vaga' : 'vagas'}',
                    style: VisualBuscaEu.descricao,
                  ),
                ),
                if (carona.status != 'ATIVA')
                  Flexible(
                    child: SeloBuscaEu(
                      texto: carona.encerradaPorTempo
                          ? 'Encerrada automaticamente por tempo'
                          : carona.status,
                      cor: VisualBuscaEu.secundario,
                    ),
                  ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.primary,
                  size: 20,
                ),
              ],
            ),
            if (carona.status == 'FINALIZADA' &&
                onAvaliarPassageiros != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onAvaliarPassageiros,
                icon: const Icon(Icons.star_outline),
                label: const Text('AVALIAR PASSAGEIROS'),
              ),
            ],
          ],
        ),
      ),
    ),
  );

  Widget _local(IconData icone, String texto, {bool destaque = false}) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(
        icone,
        size: 19,
        color: destaque ? AppColors.primary : VisualBuscaEu.secundario,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          texto,
          style: TextStyle(
            color: destaque ? VisualBuscaEu.texto : VisualBuscaEu.secundario,
            fontSize: destaque ? 15 : 13,
            height: 1.4,
            fontWeight: destaque ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    ],
  );
}
