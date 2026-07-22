import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../models/solicitacao_recebida.dart';
import '../services/solicitacao_service.dart';
import 'card_solicitacao_recebida.dart';
import 'componentes_padrao.dart';

class PainelSolicitacoesCarona extends StatefulWidget {
  final int idCarona;

  const PainelSolicitacoesCarona({super.key, required this.idCarona});

  @override
  State<PainelSolicitacoesCarona> createState() =>
      _PainelSolicitacoesCaronaState();
}

class _PainelSolicitacoesCaronaState extends State<PainelSolicitacoesCarona> {
  List<SolicitacaoRecebida> solicitacoes = [];
  bool carregando = true;
  int? idProcessando;

  @override
  void initState() {
    super.initState();
    carregarSolicitacoes();
  }

  Future<void> carregarSolicitacoes() async {
    final resultado = await SolicitacaoService.listarRecebidas(
      idCarona: widget.idCarona,
    );

    if (!mounted) {
      return;
    }

    final dados = resultado['dados'];
    final recebidas = dados is List<SolicitacaoRecebida>
        ? dados
        : <SolicitacaoRecebida>[];

    setState(() {
      carregando = false;
      solicitacoes = resultado['sucesso'] == true ? recebidas : [];
    });

    if (resultado['sucesso'] != true) {
      _mostrarMensagem(
        resultado['mensagem']?.toString() ?? 'Erro ao carregar solicitações',
      );
    }
  }

  Future<void> responder(SolicitacaoRecebida solicitacao, String status) async {
    setState(() {
      idProcessando = solicitacao.id;
    });

    final resultado = await SolicitacaoService.responderSolicitacao(
      idSolicitacao: solicitacao.id,
      status: status,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      idProcessando = null;
    });

    _mostrarMensagem(
      resultado['mensagem']?.toString() ?? 'Erro ao responder solicitação',
    );

    if (resultado['sucesso'] == true) {
      await carregarSolicitacoes();
    }
  }

  void _mostrarMensagem(String mensagem) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensagem)));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Solicitações desta carona',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (carregando)
          const EstadoConteudoPadrao(
            carregando: true,
            mensagem: 'Carregando solicitações...',
          )
        else if (solicitacoes.isEmpty)
          const EstadoConteudoPadrao(
            icone: Icons.inbox_outlined,
            mensagem: 'Nenhuma solicitação para esta carona',
          )
        else
          ListView.separated(
            itemCount: solicitacoes.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final solicitacao = solicitacoes[index];

              return CardSolicitacaoRecebida(
                solicitacao: solicitacao,
                processando: idProcessando == solicitacao.id,
                onAceitar: () => responder(solicitacao, 'ACEITA'),
                onRecusar: () => responder(solicitacao, 'RECUSADA'),
              );
            },
          ),
      ],
    );
  }
}
