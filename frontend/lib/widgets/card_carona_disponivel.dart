import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../models/carona.dart';

class CardCaronaDisponivel extends StatelessWidget {
  final Carona carona;
  final VoidCallback? onTap;
  final Widget? acaoCabecalho;
  final bool mostrarRecorrencia;

  const CardCaronaDisponivel({
    super.key,
    required this.carona,
    this.onTap,
    this.acaoCabecalho,
    this.mostrarRecorrencia = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      key: ValueKey('card-carona-${carona.id}'),
      color: carona.finalizada ? const Color(0xFFF1F1F1) : Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Motorista e valor.
              Row(
                children: [
                  const Icon(
                    Icons.directions_car_outlined,
                    color: AppColors.primary,
                    size: 26,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      carona.motorista,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    carona.valorFormatado,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (acaoCabecalho != null) ...[
                    const SizedBox(width: 4),
                    acaoCabecalho!,
                  ],
                ],
              ),

              const SizedBox(height: 20),

              Text(
                carona.rotuloHorario,
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
              const SizedBox(height: 5),

              // Horario recebe o maior destaque do card.
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 14,
                runSpacing: 8,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.access_time,
                        color: AppColors.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        carona.horarioFormatado,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _textoData(),
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              if (mostrarRecorrencia && _diasRecorrencia.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Recorrência: ${_diasRecorrencia.join(', ').toLowerCase()}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 18),

              // Destino principal da carona.
              const Text(
                'Destino',
                style: TextStyle(color: Colors.black54, fontSize: 13),
              ),
              const SizedBox(height: 5),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    color: AppColors.primary,
                    size: 21,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      carona.destino,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.person_pin_circle_outlined,
                    color: Colors.black45,
                    size: 17,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      carona.resumoInicio,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),

              const Divider(height: 28),

              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.people_outline,
                        color: Colors.black54,
                        size: 19,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        '${carona.vagas} vagas',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (carona.status != 'ATIVA') ...[
                        Text(
                          carona.status,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (onTap != null)
                        const Icon(
                          Icons.chevron_right,
                          color: AppColors.primary,
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> get _diasRecorrencia {
    final dias = carona.idRecorrencia != null
        ? carona.diasRecorrencia
        : carona.recorrente
        ? carona.diasSemana
        : <String>[];
    return [
      'SEG',
      'TER',
      'QUA',
      'QUI',
      'SEX',
      'SAB',
      'DOM',
    ].where(dias.contains).toList();
  }

  String _textoData() {
    if (carona.recorrente && carona.diasSemana.isNotEmpty) {
      return carona.diasSemana.join(', ');
    }

    return carona.dataFormatada;
  }
}
