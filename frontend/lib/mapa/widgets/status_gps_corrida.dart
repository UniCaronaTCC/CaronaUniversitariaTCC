import 'package:flutter/material.dart';
import '../services/rastreamento_gps.dart';
import '../../widgets/visual_buscaeu.dart';

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
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cor.withValues(alpha: .15)),
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
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: VisualBuscaEu.texto,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      gps.mensagem,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: VisualBuscaEu.secundario,
                      ),
                    ),
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
