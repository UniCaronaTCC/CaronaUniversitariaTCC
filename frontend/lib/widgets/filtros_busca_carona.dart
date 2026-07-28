import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../mapa/models/localizacao_selecionada.dart';
import '../mapa/widgets/barra_pesquisa_endereco.dart';
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
        Row(
          children: [
            const Expanded(
              child: Text(
                'Filtrar caronas',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (filtrosAtivos)
              IconButton(
                tooltip: 'Limpar filtros',
                onPressed: onLimparFiltros,
                icon: const Icon(Icons.filter_alt_off_outlined),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Filtra imediatamente as caronas ja carregadas.
        BarraPesquisaEndereco(
          label: 'Destino',
          icone: Icons.location_on_outlined,
          controller: destinoController,
          onChanged: onDestinoChanged,
          onSelecionado: onDestinoSelecionado,
          padding: EdgeInsets.zero,
          elevacao: 0,
          borderRadius: 16,
          usarLabelComoHint: false,
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: CampoTextoCarona(
                label: 'Data',
                usarLabelComoHint: true,
                icone: Icons.calendar_today_outlined,
                controller: dataController,
                somenteLeitura: true,
                onTap: onSelecionarData,
                suffixIcon: const Icon(
                  Icons.arrow_drop_down,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CampoTextoCarona(
                label: 'Horário',
                usarLabelComoHint: true,
                icone: Icons.access_time,
                controller: horarioController,
                somenteLeitura: true,
                onTap: onSelecionarHorario,
                suffixIcon: const Icon(
                  Icons.arrow_drop_down,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
