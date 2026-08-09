import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../models/carona.dart';

class CardCaronaDisponivel extends StatelessWidget {
  final Carona carona;
  final VoidCallback? onTap;

  const CardCaronaDisponivel({super.key, required this.carona, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
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
                ],
              ),

              const SizedBox(height: 20),

              // Horario recebe o maior destaque do card.
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
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
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _textoData(),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),

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

              // Mostra somente uma origem aproximada, quando existir.
              if (carona.origem.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.trip_origin,
                      color: Colors.black45,
                      size: 17,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Saída em ${carona.origem}',
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
              ],

              const Divider(height: 28),

              Row(
                children: [
                  const Icon(
                    Icons.people_outline,
                    color: Colors.black54,
                    size: 19,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    '${carona.vagas} vagas',
                    style: const TextStyle(color: Colors.black54, fontSize: 14),
                  ),
                  const Spacer(),
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
                    const Icon(Icons.chevron_right, color: AppColors.primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _textoData() {
    if (carona.recorrente && carona.diasSemana.isNotEmpty) {
      return carona.diasSemana.join(', ');
    }

    return carona.dataFormatada;
  }
}
