import 'package:flutter/material.dart';
// Importa os componentes visuais do Flutter

import '../config/app_colors.dart';
// Importa as cores principais do aplicativo

class CampoRecorrenciaCarona extends StatelessWidget {
  // Informa se a recorrencia esta ativada
  final bool caronaRecorrente;

  // Guarda os dias selecionados
  final List<String> diasSelecionados;

  // Funcao chamada ao ativar ou desativar a recorrencia
  final ValueChanged<bool> onRecorrenciaChanged;

  // Funcao chamada ao selecionar ou remover um dia
  final ValueChanged<String> onDiaSelecionado;

  const CampoRecorrenciaCarona({
    super.key,
    required this.caronaRecorrente,
    required this.diasSelecionados,
    required this.onRecorrenciaChanged,
    required this.onDiaSelecionado,
  });

  // Dias que podem ser selecionados
  static const List<String> diasSemana = [
    'SEG',
    'TER',
    'QUA',
    'QUI',
    'SEX',
    'SAB',
    'DOM',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Carona recorrente',
              style: TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: const Text('Repetir esta carona em dias da semana'),
            value: caronaRecorrente,
            activeThumbColor: AppColors.primary,
            onChanged: onRecorrenciaChanged,
          ),

          // Mostra os dias somente quando a recorrencia estiver ativada
          if (caronaRecorrente) ...[
            const SizedBox(height: 12),

            const Text(
              'Dias da semana',
              style: TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: diasSemana.map((dia) {
                final selecionado = diasSelecionados.contains(dia);

                return ChoiceChip(
                  label: Text(dia),
                  selected: selecionado,
                  selectedColor: AppColors.primary,
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    color: selecionado ? Colors.white : AppColors.text,
                    fontWeight: FontWeight.w600,
                  ),
                  onSelected: (_) {
                    onDiaSelecionado(dia);
                  },
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
