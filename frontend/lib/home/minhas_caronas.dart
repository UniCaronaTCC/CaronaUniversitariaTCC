import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../models/carona.dart';
import '../models/pagamento_pix.dart';
import '../models/solicitacao_enviada.dart';
import '../models/solicitacao_recebida.dart';
import '../navigation/navegacao_principal.dart';
import '../services/auth_service.dart';
import '../services/avaliacao_service.dart';
import '../services/carona_service.dart';
import '../services/memoria_solicitacoes.dart';
import '../services/mensagem_service.dart';
import '../services/pagamento_service.dart';
import '../services/solicitacao_service.dart';
import '../widgets/barra_navegacao_home.dart';
import '../widgets/aviso_app.dart';
import '../widgets/card_solicitacao_enviada.dart';
import '../widgets/card_solicitacao_recebida.dart';
import '../widgets/componentes_padrao.dart';
import '../widgets/dialogo_avaliacao.dart';
import '../widgets/dialogo_cancelamento.dart';
import '../widgets/visual_buscaeu.dart';
import 'acompanhar_corrida.dart';
import 'detalhes_carona.dart';
import 'pagamento_pix.dart';

typedef CarregarSolicitacoes = Future<Map<String, dynamic>> Function();

class MinhasCaronasTela extends StatefulWidget {
  final int abaInicial;
  final PagamentoService? pagamentoService;
  final CarregarSolicitacoes? carregarRecebidas;
  final CarregarSolicitacoes? carregarEnviadas;
  final MemoriaSolicitacoes? memoria;
  final Future<Map<String, dynamic>> Function(int)? carregarCarona;

  const MinhasCaronasTela({
    super.key,
    this.abaInicial = 0,
    this.pagamentoService,
    this.carregarRecebidas,
    this.carregarEnviadas,
    this.memoria,
    this.carregarCarona,
  }) : assert(abaInicial == 0 || abaInicial == 1);

  @override
  State<MinhasCaronasTela> createState() => _MinhasCaronasTelaState();
}

class _MinhasCaronasTelaState extends State<MinhasCaronasTela>
    with WidgetsBindingObserver {
  List<SolicitacaoRecebida> solicitacoesRecebidas = [];
  List<SolicitacaoEnviada> solicitacoesEnviadas = [];
  bool carregando = true;
  bool get consultando => _memoria.consultando;
  String? mensagemErro;
  int? idProcessando;
  late final PagamentoService _pagamentoService;
  late final MemoriaSolicitacoes _memoria;
  late final EscopoSolicitacoes _escopo;
  bool _temListaValida = false;
  bool _dialogoAberto = false;
  int? _idAbrindoDetalhes;

  bool get _fontePersonalizada =>
      widget.memoria != null ||
      widget.carregarRecebidas != null ||
      widget.carregarEnviadas != null;
  int get _idUsuario =>
      int.tryParse(AuthService.usuarioLogado?['id']?.toString() ?? '') ?? 0;
  bool get _sessaoValida =>
      _escopo == (_idUsuario, AuthService.versaoSessao) &&
      (_fontePersonalizada || AuthService.estaLogado);
  bool get _acoesHabilitadas =>
      _sessaoValida &&
      _temListaValida &&
      _memoria.confirmada(_escopo) &&
      !consultando &&
      _idAbrindoDetalhes == null &&
      idProcessando == null &&
      !_dialogoAberto;

  bool get _podeAbrirDetalhes =>
      _sessaoValida &&
      _idAbrindoDetalhes == null &&
      idProcessando == null &&
      !_dialogoAberto;

  void _aoMudarSessao() {
    if (_fontePersonalizada) _memoria.limpar();
    if (!mounted) return;
    setState(() {
      solicitacoesRecebidas = [];
      solicitacoesEnviadas = [];
      _temListaValida = false;
      carregando = false;
      idProcessando = null;
      _idAbrindoDetalhes = null;
      mensagemErro =
          'Sua sessão mudou. Entre novamente para consultar as caronas.';
    });
  }

  void _aplicarListas(ListasSolicitacoes listas) {
    _temListaValida = true;
    solicitacoesRecebidas = listas.recebidas
        .where((item) => !item.arquivada)
        .toList();
    solicitacoesEnviadas = listas.enviadas
        .where((item) => !item.arquivada)
        .toList();
    if (_memoria.confirmada(_escopo) && !consultando) {
      SolicitacaoService.sincronizarTotalSolicitacoesPendentes(
        listas.recebidas,
        enviadas: listas.enviadas,
      );
    }
  }

  void _sincronizarMemoria() {
    if (!mounted || !_sessaoValida) return;
    setState(() {
      final listas = _memoria.ler(_escopo);
      if (listas != null) _aplicarListas(listas);
      carregando = !_temListaValida && consultando;
      mensagemErro = _memoria.erroAtualizacao;
    });
  }

  void _mostrarMensagem(String mensagem, {required TipoAviso tipo}) {
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    AvisoApp.mostrar(context, mensagem, tipo: tipo);
  }

  @override
  void initState() {
    super.initState();
    _escopo = (_idUsuario, AuthService.versaoSessao);
    _memoria =
        widget.memoria ??
        (_fontePersonalizada
            ? MemoriaSolicitacoes()
            : MemoriaSolicitacoes.compartilhada);
    final anteriores = _sessaoValida ? _memoria.ler(_escopo) : null;
    if (anteriores != null) {
      // A lista pode ser mostrada antes de estar confirmada para novas acoes.
      _temListaValida = true;
      solicitacoesRecebidas = anteriores.recebidas
          .where((item) => !item.arquivada)
          .toList();
      solicitacoesEnviadas = anteriores.enviadas
          .where((item) => !item.arquivada)
          .toList();
      carregando = false;
    }
    AuthService.alteracoesSessao.addListener(_aoMudarSessao);
    _memoria.alteracoes.addListener(_sincronizarMemoria);
    WidgetsBinding.instance.addObserver(this);
    MensagemService.versaoConversas.addListener(atualizarEstadoCaronas);
    _pagamentoService = widget.pagamentoService ?? PagamentoService();
    carregarDados(invalidar: false);
  }

  @override
  void dispose() {
    AuthService.alteracoesSessao.removeListener(_aoMudarSessao);
    _memoria.alteracoes.removeListener(_sincronizarMemoria);
    WidgetsBinding.instance.removeObserver(this);
    MensagemService.versaoConversas.removeListener(atualizarEstadoCaronas);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) atualizarEstadoCaronas();
  }

  void atualizarEstadoCaronas() => carregarDados();

  Future<void> abrirDetalhes(int idSolicitacao, int idCarona) async {
    if (!_podeAbrirDetalhes || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    setState(() => _idAbrindoDetalhes = idSolicitacao);
    try {
      final resultado = await Future.sync(
        () => (widget.carregarCarona ?? CaronaService.buscarDetalhesCarona)(
          idCarona,
        ),
      ).timeout(const Duration(seconds: 25));
      if (!mounted ||
          !_sessaoValida ||
          ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      final carona = resultado['dados'];
      if (resultado['sucesso'] != true ||
          carona is! Carona ||
          carona.id != idCarona) {
        _mostrarMensagem(
          resultado['mensagem']?.toString() ??
              'Não foi possível carregar a carona. Tente novamente.',
          tipo: TipoAviso.erro,
        );
        return;
      }
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => DetalhesCaronaTela(
            carona: carona,
            indiceNavegacaoOrigem: 2,
            permitirSolicitacao: false,
            somenteConsulta: true,
          ),
        ),
      );
    } catch (_) {
      if (mounted && _sessaoValida) {
        _mostrarMensagem(
          'Não foi possível carregar a carona. Tente novamente.',
          tipo: TipoAviso.erro,
        );
      }
      return;
    } finally {
      if (mounted) setState(() => _idAbrindoDetalhes = null);
    }
    if (mounted && _sessaoValida && ModalRoute.of(context)?.isCurrent == true) {
      await carregarDados();
    }
  }

  Future<void> carregarDados({bool invalidar = true}) async {
    if (!_sessaoValida || (!_fontePersonalizada && _idUsuario <= 0)) {
      if (!mounted) return;
      setState(() {
        solicitacoesRecebidas = [];
        solicitacoesEnviadas = [];
        _temListaValida = false;
        carregando = false;
        mensagemErro = 'Entre novamente para consultar suas caronas.';
      });
      return;
    }
    if (invalidar) _memoria.invalidar(_escopo);
    final consulta = _fontePersonalizada
        ? _memoria.atualizar(
            _escopo,
            recebidas: () => _listaValidada<SolicitacaoRecebida>(
              widget.carregarRecebidas ??
                  () => SolicitacaoService.listarRecebidas(),
            ),
            enviadas: () => _listaValidada<SolicitacaoEnviada>(
              widget.carregarEnviadas ?? SolicitacaoService.listarEnviadas,
            ),
          )
        : SolicitacaoService.atualizarListas();
    _sincronizarMemoria();
    await consulta;
    _sincronizarMemoria();
  }

  Future<Map<String, dynamic>> _listaValidada<T>(
    CarregarSolicitacoes carregar,
  ) async {
    final resultado = await carregar();
    final dados = resultado['dados'];
    if (resultado['sucesso'] == true &&
        dados is List &&
        dados.every((item) => item is T)) {
      return {...resultado, 'dados': List<T>.from(dados)};
    }
    return resultado;
  }

  Future<Map<String, dynamic>> _executarAcao(
    int id,
    Future<Map<String, dynamic>> Function() enviar,
  ) async {
    setState(() => idProcessando = id);
    _memoria.invalidar(_escopo);
    try {
      return await enviar();
    } catch (_) {
      return {
        'sucesso': false,
        'mensagem':
            'Não foi possível confirmar a operação. Atualize e tente novamente.',
      };
    } finally {
      if (_sessaoValida) _memoria.invalidar(_escopo);
    }
  }

  Future<void> _concluirAcao() async {
    if (!mounted || !_sessaoValida) return;
    await carregarDados();
    if (mounted && _sessaoValida) setState(() => idProcessando = null);
  }

  Object? _estadoSolicitacao(int id) {
    for (final item in solicitacoesRecebidas) {
      if (item.id == id) {
        return (
          item.status,
          item.statusCarona,
          item.pagamentoConfirmado,
          item.avaliada,
          item.podeAvaliar,
        );
      }
    }
    for (final item in solicitacoesEnviadas) {
      if (item.id == id) {
        return (
          item.status,
          item.statusCarona,
          item.pagamentoConfirmado,
          item.avaliada,
          item.podeAvaliar,
        );
      }
    }
    return null;
  }

  bool _confirmarDadosDoDialogo(int id, Object? anteriores) {
    if (_acoesHabilitadas && _estadoSolicitacao(id) == anteriores) return true;
    _mostrarMensagem(
      'A solicitação foi atualizada. Confira os dados e tente novamente.',
      tipo: TipoAviso.atencao,
    );
    return false;
  }

  Future<void> responder(SolicitacaoRecebida solicitacao, String status) async {
    if (!_acoesHabilitadas) return;
    final resultado = await _executarAcao(
      solicitacao.id,
      () => SolicitacaoService.responderSolicitacao(
        idSolicitacao: solicitacao.id,
        status: status,
      ),
    );

    if (!mounted || !_sessaoValida) {
      return;
    }

    _mostrarMensagem(
      resultado['mensagem']?.toString() ??
          (resultado['sucesso'] == true
              ? status == 'ACEITA'
                    ? 'Solicitação aceita'
                    : 'Solicitação recusada'
              : 'Erro ao responder solicitação'),
      tipo: resultado['sucesso'] == true ? TipoAviso.sucesso : TipoAviso.erro,
    );

    await _concluirAcao();
  }

  Future<void> avaliar(int idSolicitacao, String nome) async {
    if (!_acoesHabilitadas) return;
    final anteriores = _estadoSolicitacao(idSolicitacao);
    setState(() => _dialogoAberto = true);
    final dados = await mostrarDialogoAvaliacao(context, nome);
    if (!mounted || !_sessaoValida) return;
    setState(() => _dialogoAberto = false);
    if (dados == null || !_confirmarDadosDoDialogo(idSolicitacao, anteriores)) {
      return;
    }
    final resultado = await _executarAcao(
      idSolicitacao,
      () => AvaliacaoService.enviar(
        idSolicitacao: idSolicitacao,
        nota: dados.nota,
        comentario: dados.comentario,
      ),
    );

    if (!mounted || !_sessaoValida) {
      return;
    }

    _mostrarMensagem(
      resultado['mensagem']?.toString() ??
          (resultado['sucesso'] == true
              ? 'Avaliação enviada'
              : 'Erro ao enviar avaliação'),
      tipo: resultado['sucesso'] == true ? TipoAviso.sucesso : TipoAviso.erro,
    );

    await _concluirAcao();
  }

  Future<void> pagarComPix(SolicitacaoEnviada solicitacao) async {
    if (!_acoesHabilitadas) return;
    final resultado = await _executarAcao(
      solicitacao.id,
      () => _pagamentoService.criarOuObterPix(solicitacao.id),
    );

    if (!mounted || !_sessaoValida) {
      return;
    }

    if (resultado['sucesso'] != true) {
      _mostrarMensagem(
        resultado['mensagem']?.toString() ??
            'Não foi possível preparar o pagamento',
        tipo: TipoAviso.erro,
      );
      await _concluirAcao();
      return;
    }

    final pagamento = resultado['dados'];
    if (pagamento is! PagamentoPix ||
        pagamento.idSolicitacao != solicitacao.id ||
        ModalRoute.of(context)?.isCurrent != true) {
      await _concluirAcao();
      return;
    }

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => PagamentoPixTela(
          pagamento: pagamento,
          pagamentoService: _pagamentoService,
        ),
      ),
    );

    await _concluirAcao();
  }

  Future<void> acompanharMotorista(SolicitacaoEnviada solicitacao) async {
    if (!_acoesHabilitadas) return;
    setState(() => idProcessando = solicitacao.id);
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => AcompanharCorridaTela(solicitacao: solicitacao),
      ),
    );
    await _concluirAcao();
  }

  Future<void> cancelar({
    required int idSolicitacao,
    required bool confirmada,
    required bool motorista,
  }) async {
    if (!_acoesHabilitadas) return;
    final anteriores = _estadoSolicitacao(idSolicitacao);
    setState(() => _dialogoAberto = true);
    final confirmou = await confirmarCancelamento(
      context,
      confirmada: confirmada,
      motorista: motorista,
    );

    if (!mounted || !_sessaoValida) return;
    setState(() => _dialogoAberto = false);
    if (!confirmou || !_confirmarDadosDoDialogo(idSolicitacao, anteriores)) {
      return;
    }

    final resultado = await _executarAcao(
      idSolicitacao,
      () => SolicitacaoService.cancelarSolicitacao(idSolicitacao),
    );

    if (!mounted || !_sessaoValida) {
      return;
    }

    _mostrarMensagem(
      resultado['mensagem']?.toString() ??
          (resultado['sucesso'] == true
              ? 'Solicitação cancelada'
              : 'Erro ao cancelar'),
      tipo: resultado['sucesso'] == true ? TipoAviso.sucesso : TipoAviso.erro,
    );

    await _concluirAcao();
  }

  @override
  Widget build(BuildContext context) {
    final totalPendentes = solicitacoesRecebidas
        .where((solicitacao) => solicitacao.status == 'PENDENTE')
        .length;
    final totalAceitas = solicitacoesEnviadas
        .where((solicitacao) => solicitacao.aceiteAguardandoAcao)
        .length;

    final fonteAmpliada = MediaQuery.textScalerOf(context).scale(14) > 18;
    final subtitulo = TextPainter(
      text: TextSpan(
        text: 'Acompanhe suas solicitações',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.merge(VisualBuscaEu.descricao),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: MediaQuery.sizeOf(context).width - 48);
    final alturaCabecalho = subtitulo.height + 12 + 48;
    subtitulo.dispose();
    return VisualBuscaEu(
      child: DefaultTabController(
        initialIndex: widget.abaInicial,
        length: 2,
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Caronas'),
            backgroundColor: AppColors.background,
            foregroundColor: AppColors.text,
            elevation: 0,
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(alturaCabecalho),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
                    child: Text(
                      'Acompanhe suas solicitações',
                      style: VisualBuscaEu.descricao,
                    ),
                  ),
                  TabBar(
                    isScrollable: fonteAmpliada,
                    tabAlignment: fonteAmpliada ? TabAlignment.start : null,
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
                ],
              ),
            ),
          ),
          bottomNavigationBar: BarraNavegacaoHome(
            currentIndex: 2,
            onTap: (indice) =>
                NavegacaoPrincipal.selecionar(context, indice, indiceAtual: 2),
          ),
          body: SafeArea(
            child: Column(
              children: [
                if (_temListaValida)
                  SizedBox(
                    height: 2,
                    child: consultando
                        ? const LinearProgressIndicator(minHeight: 2)
                        : null,
                  ),
                Expanded(
                  child: !_temListaValida
                      ? _estadoGeral()
                      : TabBarView(children: [_abaRecebidas(), _abaEnviadas()]),
                ),
              ],
            ),
          ),
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

  Widget _avisoAtualizacao() => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            mensagemErro!,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ),
        IconButton(
          tooltip: 'Tentar atualizar caronas novamente',
          onPressed: consultando ? null : carregarDados,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
  );

  List<Widget> _conteudoSolicitacoesRecebidas() {
    if (solicitacoesRecebidas.isEmpty) {
      return [
        if (mensagemErro != null) _avisoAtualizacao(),
        const EstadoConteudoPadrao(
          icone: Icons.inbox_outlined,
          mensagem: 'Nenhuma solicitação recebida',
        ),
      ];
    }

    return [
      if (mensagemErro != null) _avisoAtualizacao(),
      const Text(
        'Solicitações de passageiros para suas caronas.',
        style: TextStyle(color: AppColors.text, fontSize: 15),
      ),
      const SizedBox(height: 16),
      _listaSeparada(
        solicitacoesRecebidas,
        (solicitacao) => CardSolicitacaoRecebida(
          solicitacao: solicitacao,
          onAbrirDetalhes: () =>
              abrirDetalhes(solicitacao.id, solicitacao.idCarona),
          detalhesHabilitados: _podeAbrirDetalhes,
          abrindoDetalhes: _idAbrindoDetalhes == solicitacao.id,
          processando: idProcessando == solicitacao.id,
          acoesHabilitadas: _acoesHabilitadas,
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
          if (mensagemErro != null) _avisoAtualizacao(),
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
                onAbrirDetalhes: () =>
                    abrirDetalhes(solicitacao.id, solicitacao.idCarona),
                detalhesHabilitados: _podeAbrirDetalhes,
                abrindoDetalhes: _idAbrindoDetalhes == solicitacao.id,
                processando: idProcessando == solicitacao.id,
                acoesHabilitadas: _acoesHabilitadas,
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
}
