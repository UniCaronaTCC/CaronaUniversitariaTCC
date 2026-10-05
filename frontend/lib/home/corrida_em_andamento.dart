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
import '../widgets/componentes_padrao.dart';

class CorridaEmAndamentoTela extends StatefulWidget {
  final Carona carona;

  const CorridaEmAndamentoTela({super.key, required this.carona});

  @override
  State<CorridaEmAndamentoTela> createState() => _CorridaEmAndamentoTelaState();
}

class _CorridaEmAndamentoTelaState extends State<CorridaEmAndamentoTela> {
  bool finalizando = false;
  RotaResultado? rota;
  late final RastreamentoGps _gps;
  LatLng? _localizacaoMotorista;
  double? _direcaoMotorista;
  late final ProgressoCorrida _progresso;
  DateTime? _ultimoEnvioPosicao;
  bool _enviandoPosicao = false;
  bool _envioPosicaoAtivo = true;

  static const _intervaloEnvioPosicao = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _progresso = ProgressoCorrida(widget.carona.id);
    _progresso.sincronizar();
    _gps = RastreamentoGps(onPosicao: _processarPosicao);
    _gps.iniciar();
  }

  void _processarPosicao(Position posicao) {
    if (!mounted) return;

    final anterior = _localizacaoMotorista;
    final recebida = LatLng(posicao.latitude, posicao.longitude);
    final atual = _suavizarPosicao(anterior, recebida, posicao.accuracy);
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

  LatLng _suavizarPosicao(LatLng? anterior, LatLng recebida, double precisao) {
    if (anterior == null) return recebida;

    final distancia = const Distance().as(LengthUnit.Meter, anterior, recebida);
    if (distancia < 2) return anterior;

    final pesoNovaPosicao = precisao <= 15 ? 0.75 : 0.5;
    return LatLng(
      anterior.latitude +
          (recebida.latitude - anterior.latitude) * pesoNovaPosicao,
      anterior.longitude +
          (recebida.longitude - anterior.longitude) * pesoNovaPosicao,
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
      await CaronaService.atualizarPosicaoAtual(
        idCarona: widget.carona.id,
        latitude: ponto.latitude,
        longitude: ponto.longitude,
        direcao: direcaoNormalizada,
        precisao: precisao,
      );
    } finally {
      _enviandoPosicao = false;
    }
  }

  @override
  void dispose() {
    _envioPosicaoAtivo = false;
    _gps.dispose();
    _progresso.dispose();
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

    final mensagem =
        resultado['mensagem']?.toString() ??
        'Não foi possível finalizar a corrida';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensagem)));
    final carona = resultado['dados'];
    if (resultado['sucesso'] == true && carona is Carona) {
      Navigator.pop(context, carona);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const BarraSuperiorPadrao(titulo: 'Corrida em andamento'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            children: [
              StatusGpsCorrida(gps: _gps),
              StatusProgressoCorrida(progresso: _progresso),
              const SizedBox(height: 10),
              Expanded(
                child: ListenableBuilder(
                  listenable: Listenable.merge([_gps, _progresso]),
                  builder: (_, _) => !_progresso.carregado
                      ? const Center(
                          child: Text('Aguardando sincronização dos pontos...'),
                        )
                      : MapaNavegacaoCarona(
                          carona: widget.carona,
                          erroLocalizacao: _gps.precisaAtencao
                              ? _gps.mensagem
                              : null,
                          localizacaoMotorista: _localizacaoMotorista,
                          direcaoMotorista: _direcaoMotorista,
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
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      distanciaFormatada,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      duracaoFormatada,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 46,
                child: FilledButton.icon(
                  onPressed: finalizando ? null : finalizarCorrida,
                  icon: finalizando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.flag_outlined, size: 18),
                  label: Text(finalizando ? 'FINALIZANDO...' : 'FINALIZAR'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
