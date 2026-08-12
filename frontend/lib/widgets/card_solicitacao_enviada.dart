import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../models/solicitacao_enviada.dart';
import 'status_solicitacao.dart';

class CardSolicitacaoEnviada extends StatelessWidget {
  final SolicitacaoEnviada solicitacao;
  final bool processando;
  final VoidCallback? onAvaliar;

  const CardSolicitacaoEnviada({
    super.key,
    required this.solicitacao,
    this.processando = false,
    this.onAvaliar,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.directions_car_outlined,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    solicitacao.motorista,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  solicitacao.valorFormatado,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: StatusSolicitacao(status: solicitacao.status),
            ),
            const SizedBox(height: 16),
            _LinhaSolicitacao(
              icone: Icons.access_time,
              texto:
                  '${solicitacao.horarioFormatado} · ${solicitacao.dataFormatada}',
              destaque: true,
            ),
            const SizedBox(height: 12),
            _LinhaSolicitacao(
              icone: Icons.location_on_outlined,
              texto: solicitacao.destino,
            ),
            const SizedBox(height: 12),
            _LinhaSolicitacao(
              icone: Icons.person_pin_circle_outlined,
              texto: solicitacao.localEmbarque,
            ),
            if (solicitacao.podeAvaliar && onAvaliar != null) ...[
              const Divider(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: processando ? null : onAvaliar,
                  icon: const Icon(Icons.star_outline),
                  label: Text(processando ? 'ENVIANDO...' : 'AVALIAR'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LinhaSolicitacao extends StatelessWidget {
  final IconData icone;
  final String texto;
  final bool destaque;

  const _LinhaSolicitacao({
    required this.icone,
    required this.texto,
    this.destaque = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icone, color: AppColors.primary, size: 21),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            texto,
            style: TextStyle(
              color: AppColors.text,
              fontSize: destaque ? 17 : 15,
              fontWeight: destaque ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
