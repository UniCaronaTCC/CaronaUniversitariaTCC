import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../models/solicitacao_recebida.dart';
import 'status_solicitacao.dart';

class CardSolicitacaoRecebida extends StatelessWidget {
  final SolicitacaoRecebida solicitacao;
  final bool processando;
  final VoidCallback onAceitar;
  final VoidCallback onRecusar;
  final VoidCallback? onAvaliar;

  const CardSolicitacaoRecebida({
    super.key,
    required this.solicitacao,
    required this.processando,
    required this.onAceitar,
    required this.onRecusar,
    this.onAvaliar,
  });

  @override
  Widget build(BuildContext context) {
    final pendente = solicitacao.status == 'PENDENTE';

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
                const Icon(Icons.person_outline, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    solicitacao.passageiro,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                StatusSolicitacao(status: solicitacao.status),
              ],
            ),
            const SizedBox(height: 18),
            _LinhaInformacao(
              icone: Icons.access_time,
              texto:
                  '${solicitacao.horarioFormatado} · ${solicitacao.dataFormatada}',
              destaque: true,
            ),
            const SizedBox(height: 12),
            _LinhaInformacao(
              icone: Icons.location_on_outlined,
              texto: solicitacao.destino,
            ),
            const SizedBox(height: 12),
            const Text(
              'Buscar passageiro em',
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 5),
            _LinhaInformacao(
              icone: Icons.person_pin_circle_outlined,
              texto: solicitacao.localEmbarque,
            ),
            if (pendente) ...[
              const Divider(height: 30),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: processando ? null : onRecusar,
                      icon: const Icon(Icons.close),
                      label: const Text('RECUSAR'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: processando ? null : onAceitar,
                      icon: processando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: const Text('ACEITAR'),
                    ),
                  ),
                ],
              ),
            ] else if (solicitacao.podeAvaliar && onAvaliar != null) ...[
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

class _LinhaInformacao extends StatelessWidget {
  final IconData icone;
  final String texto;
  final bool destaque;

  const _LinhaInformacao({
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
