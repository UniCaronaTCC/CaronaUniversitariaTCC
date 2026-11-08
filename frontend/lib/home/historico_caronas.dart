import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../models/carona.dart';
import '../models/solicitacao_enviada.dart';
import '../navigation/navegacao_principal.dart';
import '../services/avaliacao_service.dart';
import '../services/carona_service.dart';
import '../services/solicitacao_service.dart';
import '../widgets/barra_navegacao_home.dart';
import '../widgets/aviso_app.dart';
import '../widgets/card_carona_historico.dart';
import '../widgets/card_solicitacao_enviada.dart';
import '../widgets/componentes_padrao.dart';
import '../widgets/dialogo_avaliacao.dart';
import '../widgets/visual_buscaeu.dart';
import 'avaliar_passageiros.dart';
import 'detalhes_carona.dart';

typedef CarregarHistorico = Future<Map<String, dynamic>> Function();

class HistoricoCaronasTela extends StatefulWidget {
  final CarregarHistorico? carregarOfertas;
  final CarregarHistorico? carregarPedidos;
  final CarregarPassageirosAvaliacao? carregarPassageiros;

  const HistoricoCaronasTela({
    super.key,
    this.carregarOfertas,
    this.carregarPedidos,
    this.carregarPassageiros,
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
      pedidos = _listaTipada<SolicitacaoEnviada>(resultados[1]['dados'])
          .where((pedido) => pedido.status == 'ACEITA' || pedido.arquivada)
          .toList();
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

    if (ModalRoute.of(context)?.isCurrent == true) {
      AvisoApp.mostrar(
        context,
        resultado['mensagem']?.toString() ??
            (resultado['sucesso'] == true
                ? 'Avaliação enviada'
                : 'Erro ao enviar avaliação'),
        tipo: resultado['sucesso'] == true ? TipoAviso.sucesso : TipoAviso.erro,
      );
    }

    if (resultado['sucesso'] == true) {
      await carregarDados();
    }
  }

  Future<void> abrirAvaliacaoPassageiros(Carona carona) async {
    if (carona.status != 'FINALIZADA' ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => AvaliarPassageirosTela(
          idCarona: carona.id,
          carregarPassageiros: widget.carregarPassageiros,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fonteAmpliada = MediaQuery.textScalerOf(context).scale(14) > 18;
    return VisualBuscaEu(
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Histórico de caronas'),
            backgroundColor: AppColors.background,
            foregroundColor: AppColors.text,
            elevation: 0,
            bottom: TabBar(
              isScrollable: fonteAmpliada,
              tabAlignment: fonteAmpliada ? TabAlignment.start : null,
              tabs: const [
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
    final ativas = ofertas.where((carona) => !carona.encerrada).toList();
    final finalizadas = ofertas.where((carona) => carona.encerrada).toList();

    return _listaHistorico(
      tituloAtivas: 'Ofertas ativas',
      mensagemVazia: 'Você ainda não publicou caronas',
      itensAtivos: ativas,
      itensFinalizados: finalizadas,
      construirItem: (carona) => CardCaronaHistorico(
        carona: carona,
        onTap: () => abrirDetalhes(carona),
        onAvaliarPassageiros: carona.status == 'FINALIZADA'
            ? () => abrirAvaliacaoPassageiros(carona)
            : null,
      ),
    );
  }

  Widget _historicoPassageiro() {
    final proximas = pedidos.where((pedido) => !pedido.arquivada).toList();
    final finalizadas = pedidos.where((pedido) => pedido.arquivada).toList();

    return _listaHistorico(
      tituloAtivas: 'Viagens confirmadas',
      tituloEncerradas: 'Caronas encerradas',
      mensagemVazia: 'Você ainda não participou de caronas',
      itensAtivos: proximas,
      itensFinalizados: finalizadas,
      construirItem: (pedido) => CardSolicitacaoEnviada(
        solicitacao: pedido,
        processando: idProcessando == pedido.id,
        onAvaliar: pedido.podeAvaliar && !pedido.expirada
            ? () => avaliar(pedido)
            : null,
      ),
    );
  }

  Widget _listaHistorico<T>({
    required String tituloAtivas,
    String tituloEncerradas = 'Caronas encerradas',
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
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    tituloEncerradas,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Expanded(child: Divider()),
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
