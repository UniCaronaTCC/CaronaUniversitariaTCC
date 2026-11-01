import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../models/recorrencia_carona.dart';
import 'visual_buscaeu.dart';

class CardRecorrencia extends StatelessWidget {
  final RecorrenciaCarona recorrencia;
  final bool processando;
  final bool bloqueada;
  final VoidCallback onEditar;
  final VoidCallback onAlternar;

  const CardRecorrencia({
    super.key,
    required this.recorrencia,
    required this.processando,
    required this.bloqueada,
    required this.onEditar,
    required this.onAlternar,
  });

  @override
  Widget build(BuildContext context) {
    final carona = recorrencia.configuracao;
    return CartaoBuscaEu(
      chaveCartao: ValueKey('recorrencia-${recorrencia.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SeloBuscaEu(
              texto: recorrencia.ativa
                  ? 'Programação ativa'
                  : 'Programação pausada',
              cor: recorrencia.ativa
                  ? const Color(0xFF16764B)
                  : VisualBuscaEu.secundario,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            carona.destino,
            style: VisualBuscaEu.titulo.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(carona.resumoInicio, style: VisualBuscaEu.descricao),
          const SizedBox(height: 10),
          Text(carona.diasSemana.join(', '), style: VisualBuscaEu.descricao),
          const SizedBox(height: 12),
          Text(carona.rotuloHorario, style: VisualBuscaEu.descricao),
          Text(
            carona.horarioFormatado,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 14),
          CamposLadoALado(
            larguraMinima: 260,
            primeiro: OutlinedButton(
              onPressed: bloqueada ? null : onEditar,
              child: const Text('EDITAR'),
            ),
            segundo: ElevatedButton(
              onPressed: bloqueada ? null : onAlternar,
              child: Text(
                processando
                    ? 'AGUARDE...'
                    : recorrencia.ativa
                    ? 'PAUSAR'
                    : 'RETOMAR',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
