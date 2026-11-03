import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_colors.dart';

enum _EstadoAbertura { carregando, demorada, falha, concluida }

class TelaAbertura extends StatefulWidget {
  final Future<void> Function() inicializar;
  final WidgetBuilder construirDestino;

  const TelaAbertura({
    super.key,
    required this.inicializar,
    required this.construirDestino,
  });

  @override
  State<TelaAbertura> createState() => _TelaAberturaState();
}

class _TelaAberturaState extends State<TelaAbertura>
    with SingleTickerProviderStateMixin {
  static const _prazoAviso = Duration(seconds: 30);
  late final AnimationController _entrada;
  late final Animation<double> _opacidade;
  late final Animation<double> _escala;
  Timer? _avisoDemora;
  Widget? _destino;
  bool _animacaoIniciada = false;
  _EstadoAbertura _estado = _EstadoAbertura.carregando;

  @override
  void initState() {
    super.initState();
    _entrada = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    final curva = CurvedAnimation(parent: _entrada, curve: Curves.easeOutCubic);
    _opacidade = Tween<double>(begin: .65, end: 1).animate(curva);
    _escala = Tween<double>(begin: .97, end: 1).animate(curva);
    // Desenha a abertura antes de iniciar os mesmos servicos do main anterior.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _avisoDemora = Timer(_prazoAviso, () {
        if (mounted && _estado == _EstadoAbertura.carregando) {
          setState(() => _estado = _EstadoAbertura.demorada);
        }
      });
      unawaited(_inicializar());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tela = MediaQuery.of(context);
    if (tela.disableAnimations || tela.accessibleNavigation) {
      _animacaoIniciada = true;
      _entrada.value = 1;
    } else if (!_animacaoIniciada) {
      _animacaoIniciada = true;
      _entrada.forward();
    }
  }

  Future<void> _inicializar() async {
    try {
      await widget.inicializar();
      if (!mounted) return;
      setState(() => _estado = _EstadoAbertura.concluida);
    } catch (_) {
      if (!mounted) return;
      setState(() => _estado = _EstadoAbertura.falha);
    } finally {
      _avisoDemora?.cancel();
      if (mounted) _entrada.stop();
    }
  }

  @override
  void dispose() {
    _avisoDemora?.cancel();
    _entrada.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_estado == _EstadoAbertura.concluida) {
      _destino ??= widget.construirDestino(context);
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarDividerColor: Colors.transparent,
        ),
        child: _destino!,
      );
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.primary,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        key: const ValueKey('tela-abertura'),
        backgroundColor: AppColors.primary,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, limites) {
              final compacta = limites.maxHeight < 420;
              final reduzirMovimento =
                  MediaQuery.disableAnimationsOf(context) ||
                  MediaQuery.accessibleNavigationOf(context);
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: limites.maxHeight,
                    minWidth: limites.maxWidth,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 24,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FadeTransition(
                          opacity: _opacidade,
                          child: ScaleTransition(
                            scale: _escala,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  'assets/imagens/simbolo_buscaeu_branco.png',
                                  key: const ValueKey('logo-abertura'),
                                  width: compacta ? 112 : 216,
                                  height: compacta ? 112 : 216,
                                  fit: BoxFit.contain,
                                  excludeFromSemantics: true,
                                ),
                                const SizedBox(height: 12),
                                const FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'BuscaEu',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 40,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: compacta ? 28 : 88),
                        if (_estado == _EstadoAbertura.carregando) ...[
                          if (!reduzirMovimento)
                            const ExcludeSemantics(
                              child: SizedBox.square(
                                dimension: 30,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                  backgroundColor: Color(0x338F16D9),
                                ),
                              ),
                            ),
                          if (!reduzirMovimento) const SizedBox(height: 16),
                          Semantics(
                            liveRegion: true,
                            child: const Text(
                              'Carregando...',
                              style: _estiloMensagem,
                            ),
                          ),
                        ] else ...[
                          Icon(
                            _estado == _EstadoAbertura.falha
                                ? Icons.error_outline_rounded
                                : Icons.schedule_rounded,
                            size: 30,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 16),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              _estado == _EstadoAbertura.falha
                                  ? 'Não foi possível iniciar o aplicativo.\nFeche e abra o BuscaEu para tentar novamente.'
                                  : 'Está demorando mais que o esperado.\nVocê pode aguardar ou reabrir o aplicativo.',
                              textAlign: TextAlign.center,
                              style: _estiloMensagem,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  static const _estiloMensagem = TextStyle(
    color: Colors.white,
    fontSize: 16,
    height: 1.4,
    letterSpacing: 0,
  );
}
