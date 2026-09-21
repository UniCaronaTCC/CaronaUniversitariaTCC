import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_colors.dart';
import '../models/conversa.dart';
import '../models/mensagem.dart';
import '../services/auth_service.dart';
import '../services/mensagem_service.dart';
import '../widgets/componentes_padrao.dart';

typedef CarregarMensagens = Future<Map<String, dynamic>> Function();
typedef EnviarMensagem = Future<Map<String, dynamic>> Function(String conteudo);

class ConversaDetalheTela extends StatefulWidget {
  final Conversa conversa;
  final int? idUsuario;
  final CarregarMensagens? carregarMensagens;
  final EnviarMensagem? enviarMensagem;
  final bool usarRealtime;

  const ConversaDetalheTela({
    super.key,
    required this.conversa,
    this.idUsuario,
    this.carregarMensagens,
    this.enviarMensagem,
    this.usarRealtime = true,
  });

  @override
  State<ConversaDetalheTela> createState() => _ConversaDetalheTelaState();
}

class _ConversaDetalheTelaState extends State<ConversaDetalheTela>
    with WidgetsBindingObserver {
  final TextEditingController campoMensagem = TextEditingController();
  final ScrollController scrollController = ScrollController();

  List<Mensagem> mensagens = [];
  bool carregando = true;
  bool enviando = false;
  String? mensagemErro;
  RealtimeChannel? canal;
  int proximoIdTemporario = -1;

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
    WidgetsBinding.instance.addObserver(this);
    carregarDados();

    if (widget.usarRealtime) {
      iniciarRealtime();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    MensagemService.pararAcompanhamento(canal);
    campoMensagem.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    rolarParaFinal();
  }

  Future<void> iniciarRealtime() async {
    try {
      final novoCanal = await MensagemService.acompanharConversa(
        widget.conversa.id,
        () => carregarDados(silencioso: true),
      );

      if (!mounted) {
        await MensagemService.pararAcompanhamento(novoCanal);
        return;
      }

      canal = novoCanal;
    } catch (erro) {
      debugPrint('Não foi possível acompanhar a conversa: $erro');
    }
  }

  Future<void> carregarDados({bool silencioso = false}) async {
    if (!silencioso) {
      setState(() {
        carregando = true;
        mensagemErro = null;
      });
    }

    final resultado =
        await (widget.carregarMensagens?.call() ??
            MensagemService.listarMensagens(widget.conversa.id));

    if (!mounted) {
      return;
    }

    if (resultado['sucesso'] == true && resultado['dados'] is List) {
      setState(() {
        final mensagensLocais = mensagens
            .where(
              (mensagem) => mensagem.estadoEnvio != EstadoEnvioMensagem.enviada,
            )
            .toList();
        mensagens = [
          ...(resultado['dados'] as List).whereType<Mensagem>(),
          ...mensagensLocais,
        ];
        carregando = false;
        mensagemErro = null;
      });
      rolarParaFinal(animar: silencioso);
      return;
    }

    if (!silencioso) {
      setState(() {
        carregando = false;
        mensagemErro =
            resultado['mensagem']?.toString() ?? 'Erro ao carregar mensagens';
      });
    }
  }

  Future<void> enviar() async {
    final texto = campoMensagem.text.trim();

    if (texto.isEmpty || enviando || widget.conversa.encerrada) {
      return;
    }

    final mensagemTemporaria = Mensagem(
      id: proximoIdTemporario--,
      conteudo: texto,
      criadoEm: DateTime.now(),
      idRemetente: idUsuarioAtual,
      estadoEnvio: EstadoEnvioMensagem.enviando,
    );

    setState(() {
      enviando = true;
      campoMensagem.clear();
      mensagens.add(mensagemTemporaria);
    });
    rolarParaFinal();

    await _enviarMensagem(mensagemTemporaria);
  }

  Future<void> _enviarMensagem(Mensagem mensagemLocal) async {
    final resultado =
        await (widget.enviarMensagem?.call(mensagemLocal.conteudo) ??
            MensagemService.enviarMensagem(
              widget.conversa.id,
              mensagemLocal.conteudo,
            ));

    if (!mounted) {
      return;
    }

    if (resultado['sucesso'] == true && resultado['dados'] is Mensagem) {
      final mensagem = resultado['dados'] as Mensagem;

      setState(() {
        enviando = false;
        mensagens.removeWhere(
          (item) => item.id == mensagemLocal.id || item.id == mensagem.id,
        );
        mensagens.add(mensagem);
      });
      rolarParaFinal();
      return;
    }

    setState(() {
      enviando = false;
      final indice = mensagens.indexWhere(
        (item) => item.id == mensagemLocal.id,
      );
      if (indice >= 0) {
        mensagens[indice] = mensagens[indice].copyWith(
          estadoEnvio: EstadoEnvioMensagem.erro,
        );
      }
    });
    rolarParaFinal();
  }

  Future<void> reenviar(Mensagem mensagem) async {
    if (enviando || widget.conversa.encerrada) {
      return;
    }

    final indice = mensagens.indexWhere((item) => item.id == mensagem.id);
    if (indice < 0) {
      return;
    }

    final mensagemEmReenvio = mensagem.copyWith(
      estadoEnvio: EstadoEnvioMensagem.enviando,
    );
    setState(() {
      enviando = true;
      mensagens[indice] = mensagemEmReenvio;
    });
    rolarParaFinal();

    await _enviarMensagem(mensagemEmReenvio);
  }

  void rolarParaFinal({bool animar = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !scrollController.hasClients) {
        return;
      }

      final posicao = scrollController.position;
      if (!posicao.hasContentDimensions) {
        return;
      }

      if (!animar) {
        scrollController.jumpTo(posicao.maxScrollExtent);
        return;
      }

      await scrollController.animateTo(
        posicao.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
      await WidgetsBinding.instance.endOfFrame;

      if (!mounted || !scrollController.hasClients) {
        return;
      }

      final posicaoAtualizada = scrollController.position;
      if (posicaoAtualizada.pixels != posicaoAtualizada.maxScrollExtent) {
        scrollController.jumpTo(posicaoAtualizada.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final nome = widget.conversa.nomeOutroParticipante(idUsuarioAtual);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              nome,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            Text(
              widget.conversa.destino,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _conteudo()),
            if (widget.conversa.encerrada) _avisoEncerrada() else _campoEnvio(),
          ],
        ),
      ),
    );
  }

  Widget _conteudo() {
    if (carregando) {
      return const EstadoConteudoPadrao(
        carregando: true,
        titulo: 'Carregando mensagens',
        mensagem: 'Buscando o histórico desta conversa.',
      );
    }

    if (mensagemErro != null) {
      return EstadoConteudoPadrao(
        icone: Icons.cloud_off_outlined,
        corIcone: const Color(0xFFB3261E),
        titulo: 'Não foi possível carregar as mensagens',
        mensagem: mensagemErro!,
        textoBotao: 'Tentar novamente',
        iconeBotao: Icons.refresh_rounded,
        onPressed: carregarDados,
      );
    }

    if (mensagens.isEmpty) {
      return EstadoConteudoPadrao(
        icone: widget.conversa.encerrada
            ? Icons.lock_outline
            : Icons.forum_outlined,
        corIcone: widget.conversa.encerrada
            ? Colors.black45
            : AppColors.primary,
        titulo: widget.conversa.encerrada
            ? 'Conversa encerrada'
            : 'Comece a conversa',
        mensagem: widget.conversa.encerrada
            ? 'Esta conversa foi encerrada antes do envio de mensagens.'
            : 'Envie uma mensagem para combinar os detalhes da carona.',
      );
    }

    return ListView.separated(
      key: const ValueKey('lista-mensagens'),
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      itemCount: mensagens.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _itemMensagem(index),
    );
  }

  Widget _itemMensagem(int index) {
    final mensagem = mensagens[index];
    final mostrarData =
        index == 0 ||
        !_mesmoDia(mensagens[index - 1].criadoEm, mensagem.criadoEm);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (mostrarData) _separadorData(mensagem.criadoEm),
        _bolhaMensagem(mensagem),
      ],
    );
  }

  Widget _separadorData(DateTime data) {
    return Padding(
      key: ValueKey('separador-data-${data.year}-${data.month}-${data.day}'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Expanded(child: Divider(color: Color(0xFFE1E1E1))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _formatarData(data),
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Expanded(child: Divider(color: Color(0xFFE1E1E1))),
        ],
      ),
    );
  }

  Widget _bolhaMensagem(Mensagem mensagem) {
    final enviada = mensagem.idRemetente == idUsuarioAtual;
    final falhou = enviada && mensagem.estadoEnvio == EstadoEnvioMensagem.erro;
    final corBolha = falhou
        ? const Color(0xFFFFF1F1)
        : enviada
        ? AppColors.primary
        : const Color(0xFFF0F0F0);
    final corTexto = falhou
        ? AppColors.text
        : enviada
        ? Colors.white
        : AppColors.text;

    return Align(
      alignment: enviada ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 7),
        decoration: BoxDecoration(
          color: corBolha,
          border: falhou ? Border.all(color: const Color(0xFFD32F2F)) : null,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              mensagem.conteudo,
              style: TextStyle(color: corTexto, fontSize: 15, height: 1.3),
            ),
            const SizedBox(height: 3),
            _rodapeMensagem(mensagem, enviada: enviada),
          ],
        ),
      ),
    );
  }

  Widget _rodapeMensagem(Mensagem mensagem, {required bool enviada}) {
    if (!enviada) {
      return Text(
        _formatarHorario(mensagem.criadoEm),
        style: const TextStyle(color: Colors.black45, fontSize: 10),
      );
    }

    switch (mensagem.estadoEnvio) {
      case EstadoEnvioMensagem.enviando:
        return const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: Colors.white70,
              ),
            ),
            SizedBox(width: 5),
            Text(
              'Enviando',
              style: TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ],
        );
      case EstadoEnvioMensagem.erro:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 13, color: Color(0xFFD32F2F)),
                SizedBox(width: 4),
                Text(
                  'Não enviada',
                  style: TextStyle(
                    color: Color(0xFFD32F2F),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            TextButton.icon(
              key: ValueKey('reenviar-mensagem-${mensagem.id}'),
              onPressed: enviando ? null : () => reenviar(mensagem),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFD32F2F),
                minimumSize: Size.zero,
                padding: const EdgeInsets.only(top: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 15),
              label: const Text('Tentar novamente'),
            ),
          ],
        );
      case EstadoEnvioMensagem.enviada:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatarHorario(mensagem.criadoEm),
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.done_rounded, size: 13, color: Colors.white70),
            const SizedBox(width: 2),
            const Text(
              'Enviada',
              style: TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ],
        );
    }
  }

  Widget _campoEnvio() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E5E5))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: campoMensagem,
              minLines: 1,
              maxLines: 4,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Mensagem',
                counterText: '',
                filled: true,
                fillColor: const Color(0xFFF4F4F4),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                border: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onSubmitted: (_) => enviar(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: 'Enviar mensagem',
            onPressed: enviando ? null : enviar,
            icon: enviando
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }

  Widget _avisoEncerrada() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: const BoxDecoration(
        color: Color(0xFFF3F3F3),
        border: Border(top: BorderSide(color: Color(0xFFE1E1E1))),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, size: 20, color: Colors.black54),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Conversa encerrada',
                  style: TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'O histórico continua disponível, mas novas mensagens não podem ser enviadas.',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatarHorario(DateTime data) {
    return '${data.hour.toString().padLeft(2, '0')}:'
        '${data.minute.toString().padLeft(2, '0')}';
  }

  bool _mesmoDia(DateTime primeira, DateTime segunda) {
    return primeira.year == segunda.year &&
        primeira.month == segunda.month &&
        primeira.day == segunda.day;
  }

  String _formatarData(DateTime data) {
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final diaDaMensagem = DateTime(data.year, data.month, data.day);
    final diferenca = hoje.difference(diaDaMensagem).inDays;

    if (diferenca == 0) {
      return 'Hoje';
    }
    if (diferenca == 1) {
      return 'Ontem';
    }

    const meses = [
      'janeiro',
      'fevereiro',
      'março',
      'abril',
      'maio',
      'junho',
      'julho',
      'agosto',
      'setembro',
      'outubro',
      'novembro',
      'dezembro',
    ];
    final dataFormatada = '${data.day} de ${meses[data.month - 1]}';

    if (data.year == agora.year) {
      return dataFormatada;
    }
    return '$dataFormatada de ${data.year}';
  }
}
