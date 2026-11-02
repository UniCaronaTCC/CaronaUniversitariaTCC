import 'package:flutter/material.dart';

enum TipoAviso { informacao, sucesso, atencao, erro }

class AvisoApp extends StatelessWidget {
  final String mensagem;
  final TipoAviso tipo;
  final SnackBarAction? acao;

  const AvisoApp({
    super.key,
    required this.mensagem,
    this.tipo = TipoAviso.informacao,
    this.acao,
  });

  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? mostrar(
    BuildContext context,
    String mensagem, {
    TipoAviso tipo = TipoAviso.informacao,
    SnackBarAction? acao,
    Duration? duracao,
  }) {
    if (!context.mounted) return null;
    final estilo = _estilo(tipo);
    final acessibilidade = MediaQuery.of(context);
    final semAnimacao =
        acessibilidade.disableAnimations || acessibilidade.accessibleNavigation;
    return ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: AvisoApp(mensagem: mensagem, tipo: tipo, acao: acao),
        backgroundColor: Colors.transparent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        padding: EdgeInsets.zero,
        clipBehavior: Clip.none,
        showCloseIcon: false,
        dismissDirection: DismissDirection.down,
        duration: duracao ?? _duracao(mensagem, estilo.duracao, acao != null),
        // O leitor de tela pode anunciar e dispensar o aviso sem pressa.
        persist: acessibilidade.accessibleNavigation,
      ),
      snackBarAnimationStyle: semAnimacao
          ? AnimationStyle.noAnimation
          : const AnimationStyle(
              duration: Duration(milliseconds: 360),
              reverseDuration: Duration(milliseconds: 240),
            ),
    );
  }

  static Duration _duracao(String mensagem, Duration padrao, bool temAcao) {
    final leitura = mensagem.runes.length > 60
        ? Duration(seconds: (mensagem.runes.length / 25).ceil().clamp(3, 10))
        : Duration.zero;
    final base = temAcao ? const Duration(seconds: 8) : padrao;
    return leitura > base ? leitura : base;
  }

  static ({
    Color fundo,
    Color conteudo,
    IconData icone,
    String rotulo,
    Duration duracao,
  })
  _estilo(TipoAviso tipo) => switch (tipo) {
    TipoAviso.sucesso => (
      fundo: const Color(0xFF15803D),
      conteudo: Colors.white,
      icone: Icons.check_circle_outline_rounded,
      rotulo: 'Sucesso',
      duracao: const Duration(seconds: 2),
    ),
    TipoAviso.informacao => (
      fundo: const Color(0xFFF2E8FC),
      conteudo: const Color(0xFF57108A),
      icone: Icons.info_outline_rounded,
      rotulo: 'Informação',
      duracao: const Duration(seconds: 4),
    ),
    TipoAviso.atencao => (
      fundo: const Color(0xFFFFF3D6),
      conteudo: const Color(0xFF754900),
      icone: Icons.warning_amber_rounded,
      rotulo: 'Atenção',
      duracao: const Duration(seconds: 4),
    ),
    TipoAviso.erro => (
      fundo: const Color(0xFFC62828),
      conteudo: Colors.white,
      icone: Icons.error_outline_rounded,
      rotulo: 'Erro',
      duracao: const Duration(seconds: 5),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final estilo = _estilo(tipo);
    final tela = MediaQuery.of(context);
    final alturaDisponivel =
        (tela.size.height - tela.viewInsets.bottom - tela.viewPadding.vertical)
            .clamp(0.0, double.infinity);
    final mensagemVisual = Semantics(
      label: '${estilo.rotulo}. $mensagem',
      excludeSemantics: true,
      child: Row(
        children: [
          Icon(estilo.icone, size: 22, color: estilo.conteudo),
          const SizedBox(width: 10),
          Expanded(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: alturaDisponivel * 0.5),
              child: SingleChildScrollView(
                primary: false,
                child: Text(
                  mensagem,
                  style: TextStyle(
                    color: estilo.conteudo,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    // A acao dentro do conteudo recebe largura limitada, inclusive com fonte ampliada.
    final conteudo = acao == null
        ? mensagemVisual
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              mensagemVisual,
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: SnackBarAction(
                  key: acao!.key,
                  label: acao!.label,
                  onPressed: acao!.onPressed,
                  textColor: acao!.textColor ?? estilo.conteudo,
                  disabledTextColor: acao!.disabledTextColor,
                  backgroundColor: acao!.backgroundColor,
                  disabledBackgroundColor: acao!.disabledBackgroundColor,
                ),
              ),
            ],
          );
    final cartao = Material(
      color: estilo.fundo,
      elevation: 3,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: conteudo,
      ),
    );
    final animacao = context
        .findAncestorWidgetOfExactType<SnackBar>()
        ?.animation;
    if (animacao == null ||
        tela.disableAnimations ||
        tela.accessibleNavigation) {
      return cartao;
    }
    // Reutiliza o ciclo nativo: nao cria timers nem controladores independentes.
    return AnimatedBuilder(
      animation: animacao,
      child: cartao,
      builder: (context, child) {
        final saindo = animacao.status == AnimationStatus.reverse;
        // O fade nativo comeca perto de 40% do ciclo de entrada.
        final valor = saindo
            ? animacao.value
            : ((animacao.value - 0.35) / 0.65).clamp(0.0, 1.0);
        final curva = saindo ? Curves.easeInCubic : Curves.easeOutCubic;
        final progresso = curva.transform(valor);
        return Transform.translate(
          key: const ValueKey('movimento-aviso'),
          offset: Offset(0, 28 * (1 - progresso)),
          child: Transform.scale(
            key: const ValueKey('escala-aviso'),
            scale: 0.94 + 0.06 * progresso,
            child: child,
          ),
        );
      },
    );
  }
}
