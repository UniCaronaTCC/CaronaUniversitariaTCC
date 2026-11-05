import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../config/app_colors.dart';
import '../mapa/widgets/mapa_navegacao_carona.dart';
import '../mapa/services/rota_service.dart';
import '../mapa/services/rastreamento_gps.dart';
import '../mapa/widgets/status_gps_corrida.dart';
import '../models/carona.dart';
import '../mapa/services/progresso_corrida.dart';
import '../mapa/widgets/status_progresso_corrida.dart';
import '../services/carona_service.dart';
import '../services/estado_corrida.dart';
import '../widgets/aviso_app.dart';
import '../widgets/componentes_padrao.dart';
import '../widgets/visual_buscaeu.dart';

class CorridaEmAndamentoTela extends StatefulWidget {
  final Carona carona;
  final Future<Map<String, dynamic>> Function(int)? carregarEstado;

  const CorridaEmAndamentoTela({
    super.key,
    required this.carona,
    this.carregarEstado,
  });

  @override
  State<CorridaEmAndamentoTela> createState() => _CorridaEmAndamentoTelaState();
}

class _CorridaEmAndamentoTelaState extends State<CorridaEmAndamentoTela>
    with WidgetsBindingObserver {
  bool finalizando = false;
  RotaResultado? rota;
  late final RastreamentoGps _gps;
  LatLng? _localizacaoMotorista;
  double? _direcaoMotorista;
  double? _precisaoMotorista;
  late final ProgressoCorrida _progresso;
  DateTime? _ultimoEnvioPosicao;
  bool _enviandoPosicao = false;
  bool _envioPosicaoAtivo = true;
  bool _rastreamentoEncerrado = false;
  Carona? _caronaEncerrada;
  late final EstadoCorrida _estadoCorrida;

  static const _intervaloEnvioPosicao = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _progresso = ProgressoCorrida(widget.carona.id);
    _progresso.iniciar();
    _gps = RastreamentoGps(onPosicao: _processarPosicao);
    _gps.iniciar();
    _estadoCorrida = EstadoCorrida(
      idCarona: widget.carona.id,
      onEncerrada: _receberEncerramento,
      carregar: widget.carregarEstado ?? CaronaService.buscarDetalhesCarona,
    );
    _estadoCorrida.iniciar();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_estadoCorrida.consultar());
      unawaited(_progresso.sincronizar());
    }
  }

  void _pararRastreamento() {
    if (_rastreamentoEncerrado) return;
    _rastreamentoEncerrado = true;
    _envioPosicaoAtivo = false;
    _gps.dispose();
    _progresso.dispose();
  }

  void _receberEncerramento(Carona carona) {
    if (!mounted) return;
    _pararRastreamento();
    setState(() => _caronaEncerrada = carona);
  }

  void _processarPosicao(Position posicao) {
    if (!mounted || _rastreamentoEncerrado) return;

    final anterior = _localizacaoMotorista;
    // A animação visual pertence ao mapa. Rota e servidor recebem o GPS filtrado.
    final atual = LatLng(posicao.latitude, posicao.longitude);
    _progresso.observar(posicao);
    double? novaDirecao;
    if (posicao.speed >= 1 &&
        posicao.heading.isFinite &&
        posicao.heading >= 0) {
      novaDirecao = posicao.heading;
    } else if (posicao.speed >= 1 &&
        anterior != null &&
        const Distance().as(LengthUnit.Meter, anterior, atual) >= 10) {
      novaDirecao = Geolocator.bearingBetween(
        anterior.latitude,
        anterior.longitude,
        atual.latitude,
        atual.longitude,
      );
    }

    setState(() {
      _localizacaoMotorista = atual;
      _precisaoMotorista = posicao.accuracy;
      if (novaDirecao != null) {
        _direcaoMotorista = (novaDirecao % 360 + 360) % 360;
      }
    });
    unawaited(
      _enviarPosicaoSeNecessario(
        ponto: atual,
        precisao: posicao.accuracy,
        direcao: _direcaoMotorista,
      ),
    );
  }

  Future<void> _enviarPosicaoSeNecessario({
    required LatLng ponto,
    required double precisao,
    required double? direcao,
  }) async {
    if (!_envioPosicaoAtivo || _enviandoPosicao) return;

    final agora = DateTime.now();
    final ultimoEnvio = _ultimoEnvioPosicao;
    if (ultimoEnvio != null &&
        agora.difference(ultimoEnvio) < _intervaloEnvioPosicao) {
      return;
    }

    _ultimoEnvioPosicao = agora;
    _enviandoPosicao = true;
    final direcaoNormalizada = direcao == null
        ? null
        : ((direcao % 360) + 360) % 360;

    try {
      final enviada = await CaronaService.atualizarPosicaoAtual(
        idCarona: widget.carona.id,
        latitude: ponto.latitude,
        longitude: ponto.longitude,
        direcao: direcaoNormalizada,
        precisao: precisao,
      );
      if (!enviada) unawaited(_estadoCorrida.consultar());
    } finally {
      _enviandoPosicao = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _estadoCorrida.dispose();
    _pararRastreamento();
    super.dispose();
  }

  String get distanciaFormatada => rota == null
      ? '-- km'
      : '${(rota!.distanciaMetros / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';

  String get duracaoFormatada {
    if (rota == null) return '-- min';
    final minutos = (rota!.duracaoSegundos / 60).ceil();
    if (minutos < 60) return '$minutos min';
    final restante = minutos % 60;
    return '${minutos ~/ 60} h${restante == 0 ? '' : ' $restante min'}';
  }

  Future<void> finalizarCorrida() async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finalizar corrida?'),
        content: const Text(
          'A corrida será encerrada e ficará disponível no histórico.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('FINALIZAR'),
          ),
        ],
      ),
    );
    if (confirmou != true || !mounted) return;

    setState(() => finalizando = true);
    final resultado = await CaronaService.finalizarCorrida(widget.carona.id);
    if (!mounted) return;
    setState(() => finalizando = false);

    final carona = resultado['dados'];
    final sucesso = resultado['sucesso'] == true && carona is Carona;
    if (ModalRoute.of(context)?.isCurrent == true) {
      AvisoApp.mostrar(
        context,
        resultado['mensagem']?.toString() ??
            (sucesso
                ? 'Corrida finalizada com sucesso'
                : 'Não foi possível finalizar a corrida'),
        tipo: sucesso ? TipoAviso.sucesso : TipoAviso.erro,
      );
    }
    if (sucesso) {
      _receberEncerramento(carona);
      if (ModalRoute.of(context)?.isCurrent == true) {
        Navigator.pop(context, carona);
      }
    } else {
      await _estadoCorrida.consultar();
    }
  }

  @override
  Widget build(BuildContext context) =>
      VisualBuscaEu(child: Builder(builder: _conteudo));

  Widget _conteudo(BuildContext context) {
    final encerrada = _caronaEncerrada;
    if (encerrada != null) {
      return Scaffold(
        appBar: const BarraSuperiorPadrao(titulo: 'Corrida encerrada'),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: EstadoConteudoPadrao(
                icone: Icons.timer_off_outlined,
                titulo: encerrada.encerradaPorTempo
                    ? 'Encerrada automaticamente por tempo'
                    : 'Esta corrida foi encerrada',
                mensagem: 'A corrida está disponível no histórico.',
                textoBotao: 'Voltar aos detalhes',
                onPressed: () => Navigator.pop(context, encerrada),
              ),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const BarraSuperiorPadrao(titulo: 'Corrida em andamento'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: LayoutBuilder(
            builder: (context, limites) => Column(
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: limites.maxHeight * .5,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        StatusGpsCorrida(gps: _gps),
                        const SizedBox(height: 10),
                        StatusProgressoCorrida(progresso: _progresso),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListenableBuilder(
                    listenable: Listenable.merge([_gps, _progresso]),
                    builder: (_, _) => !_progresso.carregado
                        ? const Center(
                            child: Text(
                              'Aguardando sincronização dos pontos...',
                            ),
                          )
                        : MapaNavegacaoCarona(
                            carona: widget.carona,
                            pontosPercurso: _progresso.pontos,
                            erroLocalizacao: _gps.precisaAtencao
                                ? _gps.mensagem
                                : null,
                            localizacaoMotorista: _localizacaoMotorista,
                            direcaoMotorista: _direcaoMotorista,
                            precisaoMotorista: _precisaoMotorista,
                            embarquesConcluidos: _progresso.concluidos,
                            onRotaCarregada: (resultado) {
                              if (mounted) setState(() => rota = resultado);
                            },
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: VisualBuscaEu.borda)),
          ),
          child: LayoutBuilder(
            builder: (context, limites) {
              final resumo = Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    distanciaFormatada,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: VisualBuscaEu.texto,
                    ),
                  ),
                  Text(
                    duracaoFormatada,
                    style: const TextStyle(
                      fontSize: 12,
                      color: VisualBuscaEu.secundario,
                    ),
                  ),
                ],
              );
              final botao = FilledButton.icon(
                onPressed: finalizando ? null : finalizarCorrida,
                icon: finalizando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.flag_outlined, size: 18),
                label: Text(finalizando ? 'FINALIZANDO...' : 'FINALIZAR'),
              );
              if (limites.maxWidth >= 500) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: resumo),
                    const SizedBox(width: 16),
                    Expanded(child: botao),
                  ],
                );
              }
              return CamposLadoALado(
                larguraMinima: 260,
                primeiro: resumo,
                segundo: botao,
              );
            },
          ),
        ),
      ),
    );
  }
}
