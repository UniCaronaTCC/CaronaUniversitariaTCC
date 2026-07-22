import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../models/carona.dart';
import '../models/solicitacao_enviada.dart';
import '../models/solicitacao_recebida.dart';
import '../services/carona_service.dart';
import '../services/solicitacao_service.dart';
import '../widgets/card_carona_disponivel.dart';
import '../widgets/card_solicitacao_enviada.dart';
import '../widgets/card_solicitacao_recebida.dart';
import '../widgets/componentes_padrao.dart';
import 'detalhes_carona.dart';

class MinhasCaronasTela extends StatefulWidget {
  const MinhasCaronasTela({super.key});

  @override
  State<MinhasCaronasTela> createState() => _MinhasCaronasTelaState();
}

class _MinhasCaronasTelaState extends State<MinhasCaronasTela> {
  List<Carona> caronasOfertadas = [];
  List<SolicitacaoRecebida> solicitacoesRecebidas = [];
  List<SolicitacaoEnviada> solicitacoesEnviadas = [];
  bool carregando = true;
  String? mensagemErro;
  int? idProcessando;

  @override
  void initState() {
    super.initState();
    carregarDados();
  }

  Future<void> carregarDados() async {
    setState(() {
      carregando = true;
      mensagemErro = null;
    });

    final resultados = await Future.wait([
      CaronaService.listarMinhasCaronas(),
      SolicitacaoService.listarRecebidas(),
      SolicitacaoService.listarEnviadas(),
    ]);

    if (!mounted) {
      return;
    }

    Map<String, dynamic>? resultadoComErro;

    for (final resultado in resultados) {
      if (resultado['sucesso'] != true) {
        resultadoComErro = resultado;
        break;
      }
    }

    if (resultadoComErro != null) {
      final mensagem =
          resultadoComErro['mensagem']?.toString() ??
          'Erro ao carregar suas caronas';

      setState(() {
        carregando = false;
        mensagemErro = mensagem;
      });
      return;
    }

    setState(() {
      carregando = false;
      caronasOfertadas = _listaTipada<Carona>(resultados[0]['dados']);
      solicitacoesRecebidas = _listaTipada<SolicitacaoRecebida>(
        resultados[1]['dados'],
      );
      solicitacoesEnviadas = _listaTipada<SolicitacaoEnviada>(
        resultados[2]['dados'],
      );
    });
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          resultado['mensagem']?.toString() ?? 'Erro ao responder solicitação',
        ),
      ),
    );

    if (resultado['sucesso'] == true) {
      await carregarDados();
    }
  }

  void abrirDetalhes(Carona carona) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetalhesCaronaTela(carona: carona),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Caronas'),
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.text,
          elevation: 0,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Ofertadas'),
              Tab(text: 'Solicitadas'),
            ],
          ),
        ),
        body: SafeArea(
          child: carregando || mensagemErro != null
              ? _estadoGeral()
              : TabBarView(children: [_abaOfertadas(), _abaSolicitadas()]),
        ),
      ),
    );
  }

  Widget _estadoGeral() {
    return RefreshIndicator(
      onRefresh: carregarDados,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          if (carregando)
            const EstadoConteudoPadrao(
              carregando: true,
              mensagem: 'Carregando suas caronas...',
            )
          else
            EstadoConteudoPadrao(
              icone: Icons.cloud_off_outlined,
              mensagem: mensagemErro!,
              textoBotao: 'Tentar novamente',
              onPressed: carregarDados,
            ),
        ],
      ),
    );
  }

  Widget _abaOfertadas() {
    return RefreshIndicator(
      onRefresh: carregarDados,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Suas ofertas',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (caronasOfertadas.isEmpty)
            const EstadoConteudoPadrao(
              icone: Icons.directions_car_outlined,
              mensagem: 'Você ainda não publicou caronas',
            )
          else
            _listaSeparada(
              caronasOfertadas,
              (carona) => CardCaronaDisponivel(
                carona: carona,
                onTap: () => abrirDetalhes(carona),
              ),
            ),
          const SizedBox(height: 32),
          const Text(
            'Solicitações recebidas',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Confira onde cada passageiro deseja embarcar.',
            style: TextStyle(color: AppColors.text, fontSize: 15),
          ),
          const SizedBox(height: 16),
          if (solicitacoesRecebidas.isEmpty)
            const EstadoConteudoPadrao(
              icone: Icons.inbox_outlined,
              mensagem: 'Nenhuma solicitação recebida',
            )
          else
            _listaSeparada(
              solicitacoesRecebidas,
              (solicitacao) => CardSolicitacaoRecebida(
                solicitacao: solicitacao,
                processando: idProcessando == solicitacao.id,
                onAceitar: () => responder(solicitacao, 'ACEITA'),
                onRecusar: () => responder(solicitacao, 'RECUSADA'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _abaSolicitadas() {
    return RefreshIndicator(
      onRefresh: carregarDados,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          if (solicitacoesEnviadas.isEmpty)
            const EstadoConteudoPadrao(
              icone: Icons.outbox_outlined,
              mensagem: 'Você ainda não solicitou caronas',
            )
          else
            _listaSeparada(
              solicitacoesEnviadas,
              (solicitacao) => CardSolicitacaoEnviada(solicitacao: solicitacao),
            ),
        ],
      ),
    );
  }

  Widget _listaSeparada<T>(
    List<T> itens,
    Widget Function(T item) construirItem,
  ) {
    return ListView.separated(
      itemCount: itens.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) => construirItem(itens[index]),
    );
  }

  List<T> _listaTipada<T>(dynamic dados) {
    return dados is List<T> ? dados : <T>[];
  }
}
