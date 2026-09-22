import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../models/pagamento_pix.dart';
import '../models/solicitacao_enviada.dart';
import '../models/solicitacao_recebida.dart';
import '../navigation/navegacao_principal.dart';
import '../services/avaliacao_service.dart';
import '../services/pagamento_service.dart';
import '../services/solicitacao_service.dart';
import '../widgets/barra_navegacao_home.dart';
import '../widgets/card_solicitacao_enviada.dart';
import '../widgets/card_solicitacao_recebida.dart';
import '../widgets/componentes_padrao.dart';
import '../widgets/dialogo_avaliacao.dart';
import '../widgets/dialogo_cancelamento.dart';
import 'acompanhar_corrida.dart';
import 'pagamento_pix.dart';

typedef CarregarSolicitacoes = Future<Map<String, dynamic>> Function();

class MinhasCaronasTela extends StatefulWidget {
  final PagamentoService? pagamentoService;
  final CarregarSolicitacoes? carregarRecebidas;
  final CarregarSolicitacoes? carregarEnviadas;

  const MinhasCaronasTela({
    super.key,
    this.pagamentoService,
    this.carregarRecebidas,
    this.carregarEnviadas,
  });

  @override
  State<MinhasCaronasTela> createState() => _MinhasCaronasTelaState();
}

class _MinhasCaronasTelaState extends State<MinhasCaronasTela> {
  List<SolicitacaoRecebida> solicitacoesRecebidas = [];
  List<SolicitacaoEnviada> solicitacoesEnviadas = [];
  bool carregando = true;
  String? mensagemErro;
  int? idProcessando;
  late final PagamentoService _pagamentoService;

  @override
  void initState() {
    super.initState();
    _pagamentoService = widget.pagamentoService ?? PagamentoService();
    carregarDados();
  }

  Future<void> carregarDados() async {
    setState(() {
      carregando = true;
      mensagemErro = null;
    });

    final resultados = await Future.wait([
      widget.carregarRecebidas?.call() ?? SolicitacaoService.listarRecebidas(),
      widget.carregarEnviadas?.call() ?? SolicitacaoService.listarEnviadas(),
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

    final recebidas = _listaTipada<SolicitacaoRecebida>(resultados[0]['dados']);
    final enviadas = _listaTipada<SolicitacaoEnviada>(resultados[1]['dados']);

    SolicitacaoService.sincronizarTotalSolicitacoesPendentes(
      recebidas,
      enviadas: enviadas,
    );

    setState(() {
      carregando = false;
      solicitacoesRecebidas = recebidas
          .where(
            (solicitacao) =>
                !solicitacao.caronaFinalizada && !solicitacao.cancelada,
          )
          .toList();
      solicitacoesEnviadas = enviadas
          .where(
            (solicitacao) =>
                !solicitacao.caronaFinalizada && !solicitacao.cancelada,
          )
          .toList();
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

  Future<void> pagarComPix(SolicitacaoEnviada solicitacao) async {
    setState(() => idProcessando = solicitacao.id);
    final resultado = await _pagamentoService.criarOuObterPix(solicitacao.id);

    if (!mounted) {
      return;
    }

    setState(() => idProcessando = null);

    if (resultado['sucesso'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            resultado['mensagem']?.toString() ??
                'Não foi possível preparar o pagamento',
          ),
        ),
      );
      return;
    }

    final pagamento = resultado['dados'];
    if (pagamento is! PagamentoPix) {
      return;
    }

    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => PagamentoPixTela(pagamento: pagamento)),
    );

    if (mounted) {
      await carregarDados();
    }
  }

  Future<void> acompanharMotorista(SolicitacaoEnviada solicitacao) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => AcompanharCorridaTela(solicitacao: solicitacao),
      ),
    );
    if (mounted) await carregarDados();
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
    final totalPendentes = solicitacoesRecebidas
        .where((solicitacao) => solicitacao.status == 'PENDENTE')
        .length;
    final totalAceitas = solicitacoesEnviadas
        .where((solicitacao) => solicitacao.aceiteAguardandoAcao)
        .length;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Caronas'),
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.text,
          elevation: 0,
          bottom: TabBar(
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Recebidas'),
                    if (totalPendentes > 0) ...[
                      const SizedBox(width: 8),
                      Badge.count(
                        count: totalPendentes,
                        backgroundColor: AppColors.primary,
                      ),
                    ],
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Enviadas'),
                    if (totalAceitas > 0) ...[
                      const SizedBox(width: 8),
                      Badge.count(
                        count: totalAceitas,
                        backgroundColor: AppColors.primary,
                      ),
                    ],
                  ],
                ),
              ),
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
              : TabBarView(children: [_abaRecebidas(), _abaEnviadas()]),
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

  Widget _abaRecebidas() {
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
        'Solicitações de passageiros para suas caronas.',
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

  Widget _abaEnviadas() {
    return RefreshIndicator(
      onRefresh: carregarDados,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Solicitações que você enviou como passageiro.',
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
                onPagarPix: () => pagarComPix(solicitacao),
                onAvaliar: () => avaliar(solicitacao.id, solicitacao.motorista),
                onAcompanhar: () => acompanharMotorista(solicitacao),
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
