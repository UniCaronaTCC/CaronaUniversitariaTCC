import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../models/carona.dart';
import '../models/solicitacao_enviada.dart';
import '../models/solicitacao_recebida.dart';
import '../navigation/navegacao_principal.dart';
import '../services/carona_service.dart';
import '../services/avaliacao_service.dart';
import '../services/solicitacao_service.dart';
import '../widgets/barra_navegacao_home.dart';
import '../widgets/card_carona_disponivel.dart';
import '../widgets/card_solicitacao_enviada.dart';
import '../widgets/card_solicitacao_recebida.dart';
import '../widgets/componentes_padrao.dart';
import '../widgets/dialogo_avaliacao.dart';
import 'detalhes_carona.dart';

enum FiltroOfertadas { solicitacoes, ofertas }

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
  FiltroOfertadas filtroOfertadas = FiltroOfertadas.solicitacoes;

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

  Future<void> abrirDetalhes(Carona carona) async {
    final alterada = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => DetalhesCaronaTela(carona: carona),
      ),
    );

    if (alterada == true) {
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
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Ofertadas'),
              Tab(text: 'Solicitadas'),
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
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<FiltroOfertadas>(
              segments: const [
                ButtonSegment(
                  value: FiltroOfertadas.solicitacoes,
                  label: Text('Solicitações'),
                  icon: Icon(Icons.inbox_outlined),
                ),
                ButtonSegment(
                  value: FiltroOfertadas.ofertas,
                  label: Text('Suas ofertas'),
                  icon: Icon(Icons.directions_car_outlined),
                ),
              ],
              selected: {filtroOfertadas},
              onSelectionChanged: (selecao) {
                setState(() {
                  filtroOfertadas = selecao.first;
                });
              },
            ),
          ),
          const SizedBox(height: 24),
          if (filtroOfertadas == FiltroOfertadas.solicitacoes)
            ..._conteudoSolicitacoesRecebidas()
          else
            ..._conteudoOfertas(),
        ],
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
        'Confira onde cada passageiro deseja embarcar.',
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
        ),
      ),
    ];
  }

  List<Widget> _conteudoOfertas() {
    if (caronasOfertadas.isEmpty) {
      return const [
        EstadoConteudoPadrao(
          icone: Icons.directions_car_outlined,
          mensagem: 'Você ainda não publicou caronas',
        ),
      ];
    }

    final caronasAtivas = caronasOfertadas
        .where((carona) => !carona.finalizada)
        .toList();
    final caronasFinalizadas = caronasOfertadas
        .where((carona) => carona.finalizada)
        .toList();

    return [
      if (caronasAtivas.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: Text(
              'Nenhuma carona ativa',
              style: TextStyle(color: Colors.black54),
            ),
          ),
        )
      else
        _listaSeparada(
          caronasAtivas,
          (carona) => CardCaronaDisponivel(
            carona: carona,
            onTap: () => abrirDetalhes(carona),
          ),
        ),
      if (caronasFinalizadas.isNotEmpty) ...[
        const SizedBox(height: 32),
        const Row(
          children: [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Caronas finalizadas',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 16),
        _listaSeparada(
          caronasFinalizadas,
          (carona) => CardCaronaDisponivel(
            carona: carona,
            onTap: () => abrirDetalhes(carona),
          ),
        ),
      ],
    ];
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
              (solicitacao) => CardSolicitacaoEnviada(
                solicitacao: solicitacao,
                processando: idProcessando == solicitacao.id,
                onAvaliar: () => avaliar(solicitacao.id, solicitacao.motorista),
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
