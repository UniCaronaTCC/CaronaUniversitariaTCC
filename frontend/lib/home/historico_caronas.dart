import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../models/carona.dart';
import '../models/solicitacao_enviada.dart';
import '../navigation/navegacao_principal.dart';
import '../services/avaliacao_service.dart';
import '../services/carona_service.dart';
import '../services/solicitacao_service.dart';
import '../widgets/barra_navegacao_home.dart';
import '../widgets/card_carona_disponivel.dart';
import '../widgets/card_solicitacao_enviada.dart';
import '../widgets/componentes_padrao.dart';
import '../widgets/dialogo_avaliacao.dart';
import 'detalhes_carona.dart';

typedef CarregarHistorico = Future<Map<String, dynamic>> Function();

class HistoricoCaronasTela extends StatefulWidget {
  final CarregarHistorico? carregarOfertas;
  final CarregarHistorico? carregarPedidos;

  const HistoricoCaronasTela({
    super.key,
    this.carregarOfertas,
    this.carregarPedidos,
  });

  @override
  State<HistoricoCaronasTela> createState() => _HistoricoCaronasTelaState();
}

class _HistoricoCaronasTelaState extends State<HistoricoCaronasTela> {
  List<Carona> ofertas = [];
  List<SolicitacaoEnviada> pedidos = [];
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
      widget.carregarOfertas?.call() ?? CaronaService.listarMinhasCaronas(),
      widget.carregarPedidos?.call() ?? SolicitacaoService.listarEnviadas(),
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
          'Erro ao carregar o histórico';

      setState(() {
        carregando = false;
        mensagemErro = mensagem;
      });
      return;
    }

    setState(() {
      carregando = false;
      ofertas = _listaTipada<Carona>(resultados[0]['dados']);
      pedidos = _listaTipada<SolicitacaoEnviada>(
        resultados[1]['dados'],
      ).where((pedido) => pedido.status == 'ACEITA').toList();
    });
  }

  Future<void> abrirDetalhes(Carona carona) async {
    final alterada = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => DetalhesCaronaTela(carona: carona)),
    );

    if (alterada == true) {
      await carregarDados();
    }
  }

  Future<void> avaliar(SolicitacaoEnviada pedido) async {
    final dados = await mostrarDialogoAvaliacao(context, pedido.motorista);

    if (!mounted || dados == null) {
      return;
    }

    setState(() => idProcessando = pedido.id);

    final resultado = await AvaliacaoService.enviar(
      idSolicitacao: pedido.id,
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Histórico de caronas'),
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.text,
          elevation: 0,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Como motorista'),
              Tab(text: 'Como passageiro'),
            ],
          ),
        ),
        bottomNavigationBar: BarraNavegacaoHome(
          currentIndex: 3,
          onTap: (indice) =>
              NavegacaoPrincipal.selecionar(context, indice, indiceAtual: 3),
        ),
        body: SafeArea(
          child: carregando || mensagemErro != null
              ? _estadoGeral()
              : TabBarView(
                  children: [_historicoMotorista(), _historicoPassageiro()],
                ),
        ),
      ),
    );
  }

  Widget _estadoGeral() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (carregando)
          const EstadoConteudoPadrao(
            carregando: true,
            mensagem: 'Carregando histórico...',
          )
        else
          EstadoConteudoPadrao(
            icone: Icons.cloud_off_outlined,
            mensagem: mensagemErro!,
            textoBotao: 'Tentar novamente',
            onPressed: carregarDados,
          ),
      ],
    );
  }

  Widget _historicoMotorista() {
    final ativas = ofertas.where((carona) => !carona.finalizada).toList();
    final finalizadas = ofertas.where((carona) => carona.finalizada).toList();

    return _listaHistorico(
      tituloAtivas: 'Ofertas ativas',
      mensagemVazia: 'Você ainda não publicou caronas',
      itensAtivos: ativas,
      itensFinalizados: finalizadas,
      construirItem: (carona) => CardCaronaDisponivel(
        carona: carona,
        onTap: () => abrirDetalhes(carona),
      ),
    );
  }

  Widget _historicoPassageiro() {
    final proximas = pedidos
        .where((pedido) => !pedido.caronaFinalizada)
        .toList();
    final finalizadas = pedidos
        .where((pedido) => pedido.caronaFinalizada)
        .toList();

    return _listaHistorico(
      tituloAtivas: 'Viagens confirmadas',
      mensagemVazia: 'Você ainda não participou de caronas',
      itensAtivos: proximas,
      itensFinalizados: finalizadas,
      construirItem: (pedido) => CardSolicitacaoEnviada(
        solicitacao: pedido,
        processando: idProcessando == pedido.id,
        onAvaliar: pedido.podeAvaliar ? () => avaliar(pedido) : null,
      ),
    );
  }

  Widget _listaHistorico<T>({
    required String tituloAtivas,
    required String mensagemVazia,
    required List<T> itensAtivos,
    required List<T> itensFinalizados,
    required Widget Function(T item) construirItem,
  }) {
    return RefreshIndicator(
      onRefresh: carregarDados,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            tituloAtivas,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          if (itensAtivos.isEmpty && itensFinalizados.isEmpty)
            EstadoConteudoPadrao(icone: Icons.history, mensagem: mensagemVazia)
          else if (itensAtivos.isEmpty)
            const Text(
              'Nenhuma carona ativa',
              style: TextStyle(color: Colors.black54),
            )
          else
            _listaSeparada(itensAtivos, construirItem),
          if (itensFinalizados.isNotEmpty) ...[
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
            _listaSeparada(itensFinalizados, construirItem),
          ],
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
      itemBuilder: (_, index) => construirItem(itens[index]),
    );
  }

  List<T> _listaTipada<T>(dynamic dados) {
    return dados is List<T> ? dados : <T>[];
  }
}
