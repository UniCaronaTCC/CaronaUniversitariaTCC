import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../mapa/models/localizacao_selecionada.dart';
import 'campo_destino_campus.dart';
import 'campo_texto_carona.dart';

class FiltrosBuscaCarona extends StatelessWidget {
  final TextEditingController destinoController;
  final TextEditingController dataController;
  final TextEditingController horarioController;

  final bool filtrosAtivos;

  final ValueChanged<String> onDestinoChanged;
  final ValueChanged<LocalizacaoSelecionada> onDestinoSelecionado;
  final VoidCallback onSelecionarData;
  final VoidCallback onSelecionarHorario;
  final VoidCallback onLimparFiltros;

  const FiltrosBuscaCarona({
    super.key,
    required this.destinoController,
    required this.dataController,
    required this.horarioController,
    required this.filtrosAtivos,
    required this.onDestinoChanged,
    required this.onDestinoSelecionado,
    required this.onSelecionarData,
    required this.onSelecionarHorario,
    required this.onLimparFiltros,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              const Text(
                'Filtros',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (filtrosAtivos)
                Tooltip(
                  message: 'Limpar filtros',
                  child: TextButton.icon(
                    key: const ValueKey('limpar-filtros-busca'),
                    onPressed: onLimparFiltros,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                    icon: const Icon(Icons.restart_alt, size: 20),
                    label: const Text('Limpar'),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Filtra imediatamente as caronas ja carregadas.
        CampoDestinoCampus(
          controller: destinoController,
          onChanged: onDestinoChanged,
          onSelecionado: onDestinoSelecionado,
          visualAtualizado: true,
        ),
        const SizedBox(height: 16),

        LayoutBuilder(
          builder: (context, constraints) {
            final campos = [
              CampoTextoCarona(
                key: const ValueKey('filtro-data'),
                label: 'Data',
                usarLabelComoHint: true,
                visualAtualizado: true,
                hint: 'Opcional',
                icone: Icons.calendar_today_outlined,
                controller: dataController,
                somenteLeitura: true,
                onTap: onSelecionarData,
                suffixIcon: const Icon(
                  Icons.keyboard_arrow_down,
                  color: Color(0xFF646B7B),
                  size: 20,
                ),
              ),
              CampoTextoCarona(
                key: const ValueKey('filtro-horario'),
                label: 'Horário',
                usarLabelComoHint: true,
                visualAtualizado: true,
                hint: 'Opcional',
                icone: Icons.access_time,
                controller: horarioController,
                somenteLeitura: true,
                onTap: onSelecionarHorario,
                suffixIcon: const Icon(
                  Icons.keyboard_arrow_down,
                  color: Color(0xFF646B7B),
                  size: 20,
                ),
              ),
            ];
            if (constraints.maxWidth < 320 ||
                MediaQuery.textScalerOf(context).scale(16) > 20) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [campos[0], const SizedBox(height: 16), campos[1]],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: campos[0]),
                const SizedBox(width: 12),
                Expanded(child: campos[1]),
              ],
            );
          },
        ),
      ],
    );
  }
}
