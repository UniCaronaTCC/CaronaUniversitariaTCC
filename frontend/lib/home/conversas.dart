import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../models/conversa.dart';
import '../navigation/navegacao_principal.dart';
import '../services/auth_service.dart';
import '../services/mensagem_service.dart';
import '../widgets/barra_navegacao_home.dart';
import '../widgets/card_conversa.dart';
import '../widgets/componentes_padrao.dart';
import 'conversa_detalhe.dart';

typedef CarregarConversas = Future<Map<String, dynamic>> Function();

class ConversasTela extends StatefulWidget {
  final CarregarConversas? carregarConversas;
  final ValueChanged<Conversa>? abrirConversa;
  final int? idUsuario;

  const ConversasTela({
    super.key,
    this.carregarConversas,
    this.abrirConversa,
    this.idUsuario,
  });

  @override
  State<ConversasTela> createState() => _ConversasTelaState();
}

class _ConversasTelaState extends State<ConversasTela> {
  List<Conversa> conversas = [];
  bool carregando = true;
  String? mensagemErro;

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

    if (widget.carregarConversas == null) {
      MensagemService.totalMensagensNaoLidas.addListener(
        atualizarConversasEmTempoReal,
      );
    }

    carregarDados();
  }

  @override
  void dispose() {
    MensagemService.totalMensagensNaoLidas.removeListener(
      atualizarConversasEmTempoReal,
    );
    super.dispose();
  }

  void atualizarConversasEmTempoReal() {
    carregarDados(silencioso: true);
  }

  Future<void> carregarDados({bool silencioso = false}) async {
    if (!silencioso) {
      setState(() {
        carregando = true;
        mensagemErro = null;
      });
    }

    final resultado =
        await (widget.carregarConversas?.call() ??
            MensagemService.listarConversas());

    if (!mounted) {
      return;
    }

    if (resultado['sucesso'] == true && resultado['dados'] is List) {
      setState(() {
        conversas = (resultado['dados'] as List).whereType<Conversa>().toList();
        carregando = false;
      });
      return;
    }

    setState(() {
      carregando = false;
      mensagemErro =
          resultado['mensagem']?.toString() ?? 'Erro ao carregar conversas';
    });
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
    return Scaffold(
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
      body: SafeArea(child: _conteudo()),
    );
  }

  Widget _conteudo() {
    if (carregando || mensagemErro != null) {
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

    return RefreshIndicator(
      onRefresh: carregarDados,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        itemCount: conversas.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final conversa = conversas[index];

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
