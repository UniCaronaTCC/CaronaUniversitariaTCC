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

class _ConversaDetalheTelaState extends State<ConversaDetalheTela> {
  final TextEditingController campoMensagem = TextEditingController();
  final ScrollController scrollController = ScrollController();

  List<Mensagem> mensagens = [];
  bool carregando = true;
  bool enviando = false;
  String? mensagemErro;
  RealtimeChannel? canal;

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
    carregarDados();

    if (widget.usarRealtime) {
      iniciarRealtime();
    }
  }

  @override
  void dispose() {
    MensagemService.pararAcompanhamento(canal);
    campoMensagem.dispose();
    scrollController.dispose();
    super.dispose();
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
        mensagens = (resultado['dados'] as List).whereType<Mensagem>().toList();
        carregando = false;
        mensagemErro = null;
      });
      rolarParaFinal();
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

    setState(() => enviando = true);

    final resultado =
        await (widget.enviarMensagem?.call(texto) ??
            MensagemService.enviarMensagem(widget.conversa.id, texto));

    if (!mounted) {
      return;
    }

    setState(() => enviando = false);

    if (resultado['sucesso'] == true && resultado['dados'] is Mensagem) {
      final mensagem = resultado['dados'] as Mensagem;

      setState(() {
        if (!mensagens.any((item) => item.id == mensagem.id)) {
          mensagens.add(mensagem);
        }
        campoMensagem.clear();
      });
      rolarParaFinal();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          resultado['mensagem']?.toString() ?? 'Erro ao enviar mensagem',
        ),
      ),
    );
  }

  void rolarParaFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scrollController.hasClients) {
        return;
      }

      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
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
        mensagem: 'Carregando mensagens...',
      );
    }

    if (mensagemErro != null) {
      return EstadoConteudoPadrao(
        icone: Icons.cloud_off_outlined,
        mensagem: mensagemErro!,
        textoBotao: 'Tentar novamente',
        onPressed: carregarDados,
      );
    }

    if (mensagens.isEmpty) {
      return const EstadoConteudoPadrao(
        icone: Icons.forum_outlined,
        mensagem: 'Nenhuma mensagem ainda',
      );
    }

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      itemCount: mensagens.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _bolhaMensagem(mensagens[index]),
    );
  }

  Widget _bolhaMensagem(Mensagem mensagem) {
    final enviada = mensagem.idRemetente == idUsuarioAtual;

    return Align(
      alignment: enviada ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 7),
        decoration: BoxDecoration(
          color: enviada ? AppColors.primary : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              mensagem.conteudo,
              style: TextStyle(
                color: enviada ? Colors.white : AppColors.text,
                fontSize: 15,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              _formatarHorario(mensagem.criadoEm),
              style: TextStyle(
                color: enviada ? Colors.white70 : Colors.black45,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
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
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFFF3F3F3),
        border: Border(top: BorderSide(color: Color(0xFFE1E1E1))),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, size: 18, color: Colors.black54),
          SizedBox(width: 8),
          Text(
            'Esta conversa foi encerrada',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  String _formatarHorario(DateTime data) {
    return '${data.hour.toString().padLeft(2, '0')}:'
        '${data.minute.toString().padLeft(2, '0')}';
  }
}
