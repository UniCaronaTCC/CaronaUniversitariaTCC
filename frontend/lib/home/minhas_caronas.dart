import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../models/solicitacao_enviada.dart';
import '../models/solicitacao_recebida.dart';
import '../navigation/navegacao_principal.dart';
import '../services/avaliacao_service.dart';
import '../services/solicitacao_service.dart';
import '../widgets/barra_navegacao_home.dart';
import '../widgets/card_solicitacao_enviada.dart';
import '../widgets/card_solicitacao_recebida.dart';
import '../widgets/componentes_padrao.dart';
import '../widgets/dialogo_avaliacao.dart';
import '../widgets/dialogo_cancelamento.dart';
import 'caronas_publicadas.dart';

class MinhasCaronasTela extends StatefulWidget {
  const MinhasCaronasTela({super.key});

  @override
  State<MinhasCaronasTela> createState() => _MinhasCaronasTelaState();
}

class _MinhasCaronasTelaState extends State<MinhasCaronasTela> {
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
      solicitacoesRecebidas =
          _listaTipada<SolicitacaoRecebida>(resultados[0]['dados'])
              .where(
                (solicitacao) =>
                    !solicitacao.caronaFinalizada && !solicitacao.cancelada,
              )
              .toList();
      solicitacoesEnviadas =
          _listaTipada<SolicitacaoEnviada>(resultados[1]['dados'])
              .where(
                (solicitacao) =>
                    !solicitacao.caronaFinalizada && !solicitacao.cancelada,
              )
              .toList();
    });
  }

  Future<void> abrirPublicadas() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const CaronasPublicadasTela()),
    );

    if (mounted) {
      await carregarDados();
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

  Future<void> avaliar(int idSolicitacao, String nome) async {
    final dados = await mostrarDialogoAvaliacao(context, nome);

    if (!mounted || dados == null) {
      return;
    }

    setState(() => idProcessando = idSolicitacao);

    final resultado = await AvaliacaoService.enviar(
      idSolicitacao: idSolicitacao,
      nota: dados.nota,
      comentario: dados.comentario,
    );

    if (!mounted) {
      return;
    }

    setState(() => idProcessando = null);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          resultado['mensagem']?.toString() ?? 'Erro ao enviar avaliação',
        ),
      ),
    );

    if (resultado['sucesso'] == true) {
      await carregarDados();
    }
  }

  Future<void> cancelar({
    required int idSolicitacao,
    required bool confirmada,
    required bool motorista,
  }) async {
    final confirmou = await confirmarCancelamento(
      context,
      confirmada: confirmada,
      motorista: motorista,
    );

    if (!mounted || !confirmou) {
      return;
    }

    setState(() => idProcessando = idSolicitacao);
    final resultado = await SolicitacaoService.cancelarSolicitacao(
      idSolicitacao,
    );

    if (!mounted) {
      return;
    }

    setState(() => idProcessando = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(resultado['mensagem']?.toString() ?? 'Erro ao cancelar'),
      ),
    );

    if (resultado['sucesso'] == true) {
      await carregarDados();
    }
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
          actions: [
            TextButton.icon(
              onPressed: abrirPublicadas,
              icon: const Icon(Icons.directions_car_outlined, size: 20),
              label: const Text('Publicadas'),
            ),
            const SizedBox(width: 8),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Pedidos'),
              Tab(text: 'Solicitações'),
            ],
          ),
        ),
        bottomNavigationBar: BarraNavegacaoHome(
          currentIndex: 2,
          onTap: (indice) =>
              NavegacaoPrincipal.selecionar(context, indice, indiceAtual: 2),
        ),
        body: SafeArea(
          child: carregando || mensagemErro != null
              ? _estadoGeral()
              : TabBarView(children: [_abaPedidos(), _abaSolicitacoes()]),
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

  Widget _abaSolicitacoes() {
    return RefreshIndicator(
      onRefresh: carregarDados,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: _conteudoSolicitacoesRecebidas(),
      ),
    );
  }

  List<Widget> _conteudoSolicitacoesRecebidas() {
    if (solicitacoesRecebidas.isEmpty) {
      return const [
        EstadoConteudoPadrao(
          icone: Icons.inbox_outlined,
          mensagem: 'Nenhuma solicitação recebida',
        ),
      ];
    }

    return [
      const Text(
        'Pedidos de passageiros nas caronas que você publicou.',
        style: TextStyle(color: AppColors.text, fontSize: 15),
      ),
      const SizedBox(height: 16),
      _listaSeparada(
        solicitacoesRecebidas,
        (solicitacao) => CardSolicitacaoRecebida(
          solicitacao: solicitacao,
          processando: idProcessando == solicitacao.id,
          onAceitar: () => responder(solicitacao, 'ACEITA'),
          onRecusar: () => responder(solicitacao, 'RECUSADA'),
          onAvaliar: () => avaliar(solicitacao.id, solicitacao.passageiro),
          onCancelar: () => cancelar(
            idSolicitacao: solicitacao.id,
            confirmada: true,
            motorista: true,
          ),
        ),
      ),
    ];
  }

  Widget _abaPedidos() {
    return RefreshIndicator(
      onRefresh: carregarDados,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Pedidos de vaga que você enviou para outros motoristas.',
            style: TextStyle(color: AppColors.text, fontSize: 15),
          ),
          const SizedBox(height: 16),
          if (solicitacoesEnviadas.isEmpty)
            const EstadoConteudoPadrao(
              icone: Icons.outbox_outlined,
              mensagem: 'Você ainda não solicitou caronas',
            )
          else
            _listaSeparada(
              solicitacoesEnviadas,
              (solicitacao) => CardSolicitacaoEnviada(
                solicitacao: solicitacao,
                processando: idProcessando == solicitacao.id,
                onAvaliar: () => avaliar(solicitacao.id, solicitacao.motorista),
                onCancelar: () => cancelar(
                  idSolicitacao: solicitacao.id,
                  confirmada: solicitacao.status == 'ACEITA',
                  motorista: false,
                ),
              ),
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
