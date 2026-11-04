import 'dart:async';

import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../models/conversa.dart';
import '../navigation/navegacao_principal.dart';
import '../services/auth_service.dart';
import '../services/mensagem_service.dart';
import '../services/memoria_conversas.dart';
import '../widgets/barra_navegacao_home.dart';
import '../widgets/card_conversa.dart';
import '../widgets/componentes_padrao.dart';
import '../widgets/visual_buscaeu.dart';
import 'conversa_detalhe.dart';

typedef CarregarConversas = Future<Map<String, dynamic>> Function();

class ConversasTela extends StatefulWidget {
  final CarregarConversas? carregarConversas;
  final ValueChanged<Conversa>? abrirConversa;
  final int? idUsuario;
  final DateTime Function()? agora;
  final MemoriaConversas? memoria;

  const ConversasTela({
    super.key,
    this.carregarConversas,
    this.abrirConversa,
    this.idUsuario,
    this.agora,
    this.memoria,
  });

  @override
  State<ConversasTela> createState() => _ConversasTelaState();
}

class _ConversasTelaState extends State<ConversasTela>
    with WidgetsBindingObserver {
  List<Conversa> conversas = [];
  bool carregando = true;
  String? mensagemErro;
  bool mostrarEncerradas = false;
  Timer? _timerArquivamento;
  late final MemoriaConversas _memoria;
  late final EscopoConversas _escopo;
  bool _temListaValida = false;
  Future<void>? _consulta;

  bool get _sessaoValida =>
      _escopo == (idUsuarioAtual, AuthService.versaoSessao) &&
      (widget.carregarConversas != null || AuthService.estaLogado);

  void _aoMudarSessao() {
    _memoria.limpar();
    _timerArquivamento?.cancel();
    if (!mounted) return;
    setState(() {
      conversas = [];
      _temListaValida = false;
      carregando = false;
      mensagemErro =
          'Sua sessão mudou. Entre novamente para consultar as conversas.';
    });
  }

  DateTime get agora => widget.agora?.call() ?? DateTime.now();

  void _agendarArquivamento() {
    _timerArquivamento?.cancel();
    final instante = agora;
    final prazos =
        conversas
            .where((conversa) => conversa.encerrada && !conversa.expirada)
            .map((conversa) => conversa.arquivarEm)
            .whereType<DateTime>()
            .where((prazo) => prazo.isAfter(instante))
            .toList()
          ..sort();
    if (prazos.isEmpty) return;

    _timerArquivamento = Timer(prazos.first.difference(instante), () {
      if (!mounted) return;
      setState(() {});
      _agendarArquivamento();
    });
  }

  int get idUsuarioAtual {
    if (widget.idUsuario != null) {
      return widget.idUsuario!;
    }

    return int.tryParse(AuthService.usuarioLogado?['id']?.toString() ?? '') ??
        0;
  }

  @override
  void initState() {
    super.initState();
    _escopo = (idUsuarioAtual, AuthService.versaoSessao);
    _memoria =
        widget.memoria ??
        (widget.carregarConversas == null
            ? MemoriaConversas.compartilhada
            : MemoriaConversas());
    final anteriores = _sessaoValida && idUsuarioAtual > 0
        ? _memoria.ler(_escopo)
        : null;
    if (anteriores != null) {
      conversas = anteriores;
      _temListaValida = true;
      carregando = false;
      _agendarArquivamento();
    }
    AuthService.alteracoesSessao.addListener(_aoMudarSessao);
    WidgetsBinding.instance.addObserver(this);

    if (widget.carregarConversas == null) {
      MensagemService.totalMensagensNaoLidas.addListener(
        atualizarConversasEmTempoReal,
      );
    }
    MensagemService.versaoConversas.addListener(atualizarConversasEmTempoReal);
    MensagemService.versaoListaConversas.addListener(
      atualizarConversasEmTempoReal,
    );

    carregarDados(invalidar: false);
  }

  @override
  void dispose() {
    AuthService.alteracoesSessao.removeListener(_aoMudarSessao);
    MensagemService.versaoListaConversas.removeListener(
      atualizarConversasEmTempoReal,
    );
    _timerArquivamento?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    MensagemService.totalMensagensNaoLidas.removeListener(
      atualizarConversasEmTempoReal,
    );
    MensagemService.versaoConversas.removeListener(
      atualizarConversasEmTempoReal,
    );
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {});
      _agendarArquivamento();
      carregarDados();
    }
  }

  void atualizarConversasEmTempoReal() {
    carregarDados();
  }

  Future<void> carregarDados({bool invalidar = true}) {
    if (!_sessaoValida || idUsuarioAtual <= 0) {
      _timerArquivamento?.cancel();
      if (mounted) {
        setState(() {
          conversas = [];
          _temListaValida = false;
          carregando = false;
          mensagemErro = 'Entre novamente para consultar suas conversas.';
        });
      }
      return Future<void>.value();
    }
    if (invalidar) _memoria.invalidar(_escopo);
    return _consulta ??= _carregarLista().whenComplete(() => _consulta = null);
  }

  Future<void> _carregarLista() async {
    setState(() {
      carregando = !_temListaValida;
      mensagemErro = null;
    });
    final resultado = await _memoria.atualizar(
      _escopo,
      widget.carregarConversas ?? MensagemService.listarConversas,
    );
    if (!mounted || !_sessaoValida) return;
    if (resultado['sucesso'] == true) {
      setState(() {
        conversas = resultado['dados'] as List<Conversa>;
        _temListaValida = true;
        carregando = false;
        mensagemErro = null;
      });
      _agendarArquivamento();
    } else {
      setState(() {
        carregando = false;
        mensagemErro =
            resultado['mensagem']?.toString() ?? 'Erro ao carregar conversas';
      });
    }
  }

  Future<void> abrirConversa(Conversa conversa) async {
    if (widget.abrirConversa != null) {
      widget.abrirConversa!(conversa);
      return;
    }

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ConversaDetalheTela(conversa: conversa, idUsuario: idUsuarioAtual),
      ),
    );

    if (mounted) {
      await carregarDados();
    }
  }

  @override
  Widget build(BuildContext context) {
    return VisualBuscaEu(
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Conversas'),
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.text,
          elevation: 0,
          automaticallyImplyLeading: false,
        ),
        bottomNavigationBar: BarraNavegacaoHome(
          currentIndex: 1,
          onTap: (indice) =>
              NavegacaoPrincipal.selecionar(context, indice, indiceAtual: 1),
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 8, 24, 8),
                child: Text(
                  'Combine os detalhes da sua carona',
                  style: VisualBuscaEu.descricao,
                ),
              ),
              if (_temListaValida && mensagemErro != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          mensagemErro!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Tentar atualizar conversas novamente',
                        icon: const Icon(Icons.refresh_rounded),
                        onPressed: carregarDados,
                      ),
                    ],
                  ),
                ),
              Expanded(child: _conteudo()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _conteudo() {
    if (carregando || (!_temListaValida && mensagemErro != null)) {
      return _estadoAtualizavel(
        carregando
            ? const EstadoConteudoPadrao(
                carregando: true,
                titulo: 'Carregando conversas',
                mensagem: 'Buscando suas conversas mais recentes.',
              )
            : EstadoConteudoPadrao(
                icone: Icons.cloud_off_outlined,
                corIcone: const Color(0xFFB3261E),
                titulo: 'Não foi possível carregar',
                mensagem: mensagemErro!,
                textoBotao: 'Tentar novamente',
                iconeBotao: Icons.refresh_rounded,
                onPressed: carregarDados,
              ),
      );
    }

    if (conversas.isEmpty) {
      return _estadoAtualizavel(
        const EstadoConteudoPadrao(
          icone: Icons.chat_bubble_outline,
          corIcone: AppColors.primary,
          titulo: 'Nenhuma conversa ainda',
          mensagem:
              'Quando uma solicitação de carona for aceita, a conversa aparecerá aqui.',
        ),
      );
    }

    final instante = agora;
    final recentes = conversas
        .where((conversa) => !conversa.deveArquivar(instante))
        .toList();
    final encerradas = conversas
        .where((conversa) => conversa.deveArquivar(instante))
        .toList();
    final quantidadeRecentes = recentes.isEmpty ? 1 : recentes.length;
    final quantidadeEncerradas = mostrarEncerradas
        ? (encerradas.isEmpty ? 1 : encerradas.length)
        : 0;

    return RefreshIndicator(
      onRefresh: carregarDados,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        itemCount: quantidadeRecentes + 1 + quantidadeEncerradas,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == quantidadeRecentes) {
            return Column(
              children: [
                const Divider(),
                Semantics(
                  expanded: mostrarEncerradas,
                  child: TextButton(
                    onPressed: () => setState(() {
                      mostrarEncerradas = !mostrarEncerradas;
                    }),
                    child: Row(
                      children: [
                        const Icon(Icons.archive_outlined),
                        const SizedBox(width: 12),
                        const Expanded(child: Text('Encerradas')),
                        Text('${encerradas.length}'),
                        const SizedBox(width: 8),
                        Icon(
                          mostrarEncerradas
                              ? Icons.expand_less
                              : Icons.expand_more,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }
          final recentesVazias = index < quantidadeRecentes && recentes.isEmpty;
          if (recentesVazias ||
              (index > quantidadeRecentes && encerradas.isEmpty)) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                recentesVazias
                    ? 'Nenhuma conversa recente'
                    : 'Nenhuma conversa arquivada',
                style: const TextStyle(color: Colors.black54),
              ),
            );
          }
          final conversa = index < quantidadeRecentes
              ? recentes[index]
              : encerradas[index - quantidadeRecentes - 1];

          return CardConversa(
            conversa: conversa,
            idUsuarioAtual: idUsuarioAtual,
            onTap: () => abrirConversa(conversa),
          );
        },
      ),
    );
  }

  Widget _estadoAtualizavel(Widget estado) {
    return RefreshIndicator(
      onRefresh: carregarDados,
      child: LayoutBuilder(
        builder: (context, restricoes) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: SizedBox(height: restricoes.maxHeight - 48, child: estado),
        ),
      ),
    );
  }
}
