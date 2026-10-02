import 'package:flutter/material.dart';
import '../services/rastreamento_gps.dart';

class StatusGpsCorrida extends StatelessWidget {
  final RastreamentoGps gps;
  const StatusGpsCorrida({super.key, required this.gps});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: gps,
      builder: (_, _) {
        final cor = gps.precisaAtencao ? Colors.orange.shade800 : Colors.green;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: cor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.directions_car, color: cor, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CORRIDA INICIADA',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(gps.mensagem, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              if (gps.precisaAtencao)
                IconButton(
                  onPressed: gps.iniciar,
                  tooltip: 'Tentar localização novamente',
                  icon: const Icon(Icons.refresh),
                ),
            ],
          ),
        );
      },
    );
  }
}
