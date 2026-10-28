import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../mapa/models/localizacao_selecionada.dart';
import '../mapa/screens/mapa_screen.dart';
import '../models/carona.dart';
import '../models/ponto_embarque.dart';
import '../models/solicitacao_enviada.dart';
import '../navigation/navegacao_principal.dart';
import '../services/auth_service.dart';
import '../services/carona_service.dart';
import '../services/solicitacao_service.dart';
import '../widgets/barra_navegacao_home.dart';
import '../widgets/componentes_padrao.dart';
import '../widgets/conteudo_detalhes_carona.dart';
import '../widgets/painel_solicitacoes_carona.dart';
import 'ofertar_carona.dart';
import 'corrida_em_andamento.dart';

class DetalhesCaronaTela extends StatefulWidget {
  final Carona carona;
  final int? indiceNavegacaoOrigem;
  final bool permitirSolicitacao;
  final bool somenteConsulta;
  final String? fotoMotorista;

  const DetalhesCaronaTela({
    super.key,
    required this.carona,
    this.indiceNavegacaoOrigem,
    this.permitirSolicitacao = true,
    this.somenteConsulta = false,
    this.fotoMotorista,
  });

  @override
  State<DetalhesCaronaTela> createState() => _DetalhesCaronaTelaState();
}

class _DetalhesCaronaTelaState extends State<DetalhesCaronaTela> {
  Carona? _caronaAtualizada;
  int _ultimaAtualizacao = 0;

  Carona get caronaAtual => _caronaAtualizada ?? widget.carona;

  bool get _exibeSolicitacao =>
      !widget.somenteConsulta &&
      !usuarioEhMotorista &&
      widget.permitirSolicitacao &&
      ['ATIVA', 'LOTADA', 'EM_ANDAMENTO'].contains(caronaAtual.status);

  bool _consultandoSolicitacao = true;
  bool _falhaConsultaSolicitacao = false;
  String? _statusSolicitacao;
  bool _pagamentoConfirmado = false;
  int _ultimaConsultaSolicitacao = 0;

  @override
  void initState() {
    super.initState();
    if (_exibeSolicitacao) _consultarSolicitacao();
  }

  @override
  void didUpdateWidget(covariant DetalhesCaronaTela oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.carona.id != widget.carona.id ||
        oldWidget.carona.status != widget.carona.status ||
        oldWidget.carona.idMotorista != widget.carona.idMotorista ||
        oldWidget.permitirSolicitacao != widget.permitirSolicitacao ||
        oldWidget.somenteConsulta != widget.somenteConsulta) {
      _ultimaConsultaSolicitacao++;
      _ultimaAtualizacao++;
      _caronaAtualizada = null;
      _statusSolicitacao = null;
      _pagamentoConfirmado = false;
      enviandoSolicitacao = false;
      if (_exibeSolicitacao) _consultarSolicitacao();
    }
  }

  Future<void> _consultarSolicitacao() async {
    final consulta = ++_ultimaConsultaSolicitacao;
    final idCarona = caronaAtual.id;
    setState(() {
      _consultandoSolicitacao = true;
      _falhaConsultaSolicitacao = false;
    });

    try {
      final resultado = await SolicitacaoService.listarEnviadas().timeout(
        const Duration(seconds: 20),
      );
      if (!mounted || consulta != _ultimaConsultaSolicitacao) return;

      final dados = resultado['dados'];
      if (resultado['sucesso'] != true || dados is! List<SolicitacaoEnviada>) {
        throw const FormatException('Consulta de solicitação indisponível');
      }

      SolicitacaoEnviada? existente;
      for (final solicitacao in dados) {
        if (solicitacao.idCarona == idCarona &&
            ['PENDENTE', 'ACEITA'].contains(solicitacao.status)) {
          existente = solicitacao;
          break;
        }
      }
      setState(() {
        _statusSolicitacao = existente?.status;
        _pagamentoConfirmado = existente?.pagamentoConfirmado ?? false;
        _consultandoSolicitacao = false;
      });
    } catch (_) {
      if (!mounted || consulta != _ultimaConsultaSolicitacao) return;
      setState(() {
        _consultandoSolicitacao = false;
        _falhaConsultaSolicitacao = true;
      });
    }
  }

  bool get _podeSolicitar =>
      _exibeSolicitacao &&
      !_consultandoSolicitacao &&
      !_falhaConsultaSolicitacao &&
      _statusSolicitacao == null &&
      !enviandoSolicitacao &&
      caronaAtual.status == 'ATIVA' &&
      caronaAtual.vagas > 0;

  Future<void> _atualizarCarona() async {
    final atualizacao = ++_ultimaAtualizacao;
    final idCarona = caronaAtual.id;
    try {
      final resultado = await CaronaService.listarMinhasCaronas().timeout(
        const Duration(seconds: 20),
      );
      if (!mounted || atualizacao != _ultimaAtualizacao) return;

      final dados = resultado['dados'];
      if (resultado['sucesso'] == true && dados is List<Carona>) {
        for (final carona in dados) {
          if (carona.id == idCarona) {
            setState(() => _caronaAtualizada = carona);
            return;
          }
        }
      }
    } catch (_) {
      if (!mounted || atualizacao != _ultimaAtualizacao) return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'A solicitação foi aceita, mas não foi possível atualizar o percurso.',
        ),
        action: SnackBarAction(label: 'ATUALIZAR', onPressed: _atualizarCarona),
      ),
    );
  }

  bool enviandoSolicitacao = false;
  bool excluindoCarona = false;
  bool processandoCorrida = false;

  Future<void> abrirCorrida({bool iniciar = false}) async {
    Carona carona = caronaAtual;
    if (iniciar) {
      setState(() => processandoCorrida = true);
      final resultado = await CaronaService.iniciarCorrida(carona.id);
      if (!mounted) return;
      setState(() => processandoCorrida = false);

      if (resultado['sucesso'] != true || resultado['dados'] is! Carona) {
        _mostrarMensagem(
          resultado['mensagem']?.toString() ??
              'Não foi possível iniciar a corrida',
        );
        return;
      }
      carona = resultado['dados'] as Carona;
      setState(() => _caronaAtualizada = carona);
    }

    final finalizada = await Navigator.push<Carona>(
      context,
      MaterialPageRoute(builder: (_) => CorridaEmAndamentoTela(carona: carona)),
    );
    if (!mounted || finalizada == null) return;
    setState(() => _caronaAtualizada = finalizada);
  }

  bool get usuarioEhMotorista {
    final idRecebido = AuthService.usuarioLogado?['id'];

    final idUsuario = idRecebido is int
        ? idRecebido
        : int.tryParse(idRecebido?.toString() ?? '');

    return idUsuario != null && idUsuario == caronaAtual.idMotorista;
  }

  int get indiceNavegacao =>
      widget.indiceNavegacaoOrigem ?? (usuarioEhMotorista ? 2 : 0);

  Future<void> solicitarVaga() async {
    if (!_podeSolicitar) return;
    final idCarona = caronaAtual.id;
    final escolha = await _selecionarPontoEmbarque();

    if (!mounted ||
        idCarona != caronaAtual.id ||
        escolha == null ||
        !_podeSolicitar) {
      return;
    }

    if (escolha == 'NOVO') {
      await _solicitarNovoPonto();
      return;
    }

    final ponto = escolha as PontoEmbarque;

    if (ponto.id == null) {
      _mostrarMensagem('Ponto de embarque inválido');
      return;
    }

    await _enviarSolicitacao(
      SolicitacaoService.solicitarVagaComPontoExistente(
        idCarona: caronaAtual.id,
        idPontoEmbarque: ponto.id!,
      ),
    );
  }

  Future<Object?> _selecionarPontoEmbarque() {
    return showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            children: [
              const Text(
                'Escolha o ponto de embarque',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text('Selecione um dos pontos cadastrados pelo motorista.'),
              const SizedBox(height: 16),

              if (caronaAtual.pontosEmbarque.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Nenhum ponto de embarque foi cadastrado.'),
                )
              else
                ...caronaAtual.pontosEmbarque.map(_itemPontoEmbarque),

              const Divider(height: 28),

              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.add_location_alt_outlined),
                title: const Text('Solicitar novo ponto de embarque'),
                subtitle: const Text(
                  'O motorista poderá aceitar ou recusar o novo local.',
                ),
                onTap: () => Navigator.pop(context, 'NOVO'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _itemPontoEmbarque(PontoEmbarque ponto) {
    final nome = ponto.nome?.trim();

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.location_on_outlined),
      title: Text(nome != null && nome.isNotEmpty ? nome : 'Ponto de embarque'),
      subtitle: Text(ponto.endereco),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.pop(context, ponto),
    );
  }

  Future<void> _solicitarNovoPonto() async {
    final idCarona = caronaAtual.id;
    final localEmbarque = await Navigator.push<LocalizacaoSelecionada>(
      context,
      MaterialPageRoute(
        builder: (context) => const TesteMapa(
          titulo: 'Novo ponto de embarque',
          ajusteOpcional: true,
          instrucao: 'Escolha o ponto que deseja solicitar ao motorista',
          textoBotao: 'SOLICITAR ESTE PONTO',
        ),
      ),
    );

    if (!mounted ||
        idCarona != caronaAtual.id ||
        localEmbarque == null ||
        !_podeSolicitar) {
      return;
    }

    await _enviarSolicitacao(
      SolicitacaoService.solicitarVagaComNovoPonto(
        idCarona: caronaAtual.id,
        localEmbarque: localEmbarque.endereco,
        embarqueLatitude: localEmbarque.ponto.latitude,
        embarqueLongitude: localEmbarque.ponto.longitude,
      ),
    );
  }

  Future<void> _enviarSolicitacao(
    Future<Map<String, dynamic>> requisicao,
  ) async {
    final idCarona = caronaAtual.id;
    setState(() {
      enviandoSolicitacao = true;
    });

    final resultado = await requisicao;

    if (!mounted || idCarona != caronaAtual.id) {
      return;
    }

    setState(() {
      enviandoSolicitacao = false;
      if (resultado['sucesso'] == true) {
        _statusSolicitacao = 'PENDENTE';
        _pagamentoConfirmado = false;
      }
    });

    _mostrarMensagem(
      resultado['mensagem']?.toString() ?? 'Erro ao solicitar vaga',
    );

    // Uma falha de resposta não garante que o servidor deixou de registrar.
    if (resultado['sucesso'] != true) await _consultarSolicitacao();
  }

  Future<void> editarCarona() async {
    final alterada = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => OfertarCaronaTela(
          caronaParaEditar: caronaAtual,
          indiceNavegacao: 2,
        ),
      ),
    );

    if (mounted && alterada == true) {
      Navigator.pop(context, true);
    }
  }

  Future<void> confirmarExclusao() async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir carona?'),
        content: const Text(
          'A oferta deixará de aparecer para os passageiros.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('EXCLUIR'),
          ),
        ],
      ),
    );

    if (confirmou != true || !mounted) {
      return;
    }

    setState(() {
      excluindoCarona = true;
    });

    final resultado = await CaronaService.excluirCarona(caronaAtual.id);

    if (!mounted) {
      return;
    }

    setState(() {
      excluindoCarona = false;
    });

    _mostrarMensagem(
      resultado['mensagem']?.toString() ?? 'Erro ao excluir carona',
    );

    if (resultado['sucesso'] == true) {
      Navigator.pop(context, true);
    }
  }

  void _mostrarMensagem(String mensagem) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensagem)));
  }

  @override
  Widget build(BuildContext context) {
    final permiteAcoes = [
      'ATIVA',
      'LOTADA',
      'EM_ANDAMENTO',
    ].contains(caronaAtual.status);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: BarraSuperiorPadrao(
        titulo: usuarioEhMotorista && !widget.somenteConsulta
            ? 'Gerenciar carona'
            : 'Detalhes da carona',
      ),
      body: SafeArea(
        child: ConteudoDetalhesCarona(
          carona: caronaAtual,
          somenteConsulta: widget.somenteConsulta,
          fotoMotorista: widget.fotoMotorista,
          rodape: usuarioEhMotorista && !widget.somenteConsulta
              ? PainelSolicitacoesCarona(
                  idCarona: caronaAtual.id,
                  onSolicitacaoAceita: _atualizarCarona,
                )
              : null,
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!widget.somenteConsulta && usuarioEhMotorista && permiteAcoes)
            _acoesGerenciamento()
          else if (_exibeSolicitacao)
            _rodapeSolicitacao(),

          BarraNavegacaoHome(
            currentIndex: indiceNavegacao,
            onTap: (indice) => NavegacaoPrincipal.selecionar(
              context,
              indice,
              indiceAtual: indiceNavegacao,
            ),
          ),
        ],
      ),
    );
  }

  Widget _acoesGerenciamento() {
    return SafeArea(
      top: false,
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!caronaAtual.recorrente) ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: processandoCorrida || excluindoCarona
                      ? null
                      : () => abrirCorrida(iniciar: !caronaAtual.emAndamento),
                  icon: processandoCorrida
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          caronaAtual.emAndamento
                              ? Icons.navigation_outlined
                              : Icons.play_arrow,
                        ),
                  label: Text(
                    processandoCorrida
                        ? 'INICIANDO...'
                        : caronaAtual.emAndamento
                        ? 'CONTINUAR CORRIDA'
                        : 'INICIAR CORRIDA',
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: excluindoCarona || caronaAtual.emAndamento
                        ? null
                        : confirmarExclusao,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('EXCLUIR'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: excluindoCarona || caronaAtual.emAndamento
                        ? null
                        : editarCarona,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('EDITAR'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _rodapeSolicitacao() {
    Widget conteudo;
    if (_consultandoSolicitacao) {
      conteudo = const Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Expanded(child: Text('Consultando solicitação...')),
        ],
      );
    } else if (_falhaConsultaSolicitacao) {
      conteudo = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Não foi possível consultar sua solicitação.'),
          TextButton.icon(
            onPressed: _consultarSolicitacao,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente'),
          ),
        ],
      );
    } else if (_statusSolicitacao != null) {
      final aceita = _statusSolicitacao == 'ACEITA';
      conteudo = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _pagamentoConfirmado ? Icons.check_circle_outline : Icons.schedule,
            color: AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _pagamentoConfirmado
                      ? 'Vaga confirmada'
                      : aceita
                      ? 'Solicitação aceita'
                      : 'Carona já solicitada',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  _pagamentoConfirmado
                      ? 'Seu pagamento foi confirmado.'
                      : aceita
                      ? caronaAtual.recorrente
                            ? 'Acompanhe os detalhes em Caronas.'
                            : 'Aguardando pagamento. Acompanhe em Caronas.'
                      : 'Aguardando resposta do motorista.',
                ),
              ],
            ),
          ),
        ],
      );
    } else if (caronaAtual.status != 'ATIVA' || caronaAtual.vagas <= 0) {
      conteudo = const Text(
        'Esta carona não está disponível para solicitações.',
      );
    } else {
      conteudo = SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: _podeSolicitar ? solicitarVaga : null,
          icon: enviandoSolicitacao
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.person_add_alt_1),
          label: Text(enviandoSolicitacao ? 'ENVIANDO...' : 'SOLICITAR VAGA'),
        ),
      );
    }

    return SafeArea(
      top: false,
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
        child: Semantics(liveRegion: true, child: conteudo),
      ),
    );
  }
}
