import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../config/app_colors.dart';
import '../mapa/widgets/mapa_navegacao_carona.dart';
import '../mapa/services/rota_service.dart';
import '../mapa/services/localizacao_service.dart';
import '../models/carona.dart';
import '../models/ponto_embarque.dart';
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
  StreamSubscription<Position>? _localizacaoSubscription;
  LatLng? _localizacaoMotorista;
  double? _direcaoMotorista;
  Set<int> _embarquesConcluidos = {};
  int? _pontoEmObservacao;
  int _leiturasProximas = 0;
  DateTime? _ultimoEnvioPosicao;
  bool _enviandoPosicao = false;
  bool _envioPosicaoAtivo = true;

  static const _intervaloEnvioPosicao = Duration(seconds: 5);

  int _chavePonto(PontoEmbarque ponto) => ponto.id ?? -ponto.ordem;

  PontoEmbarque? _detectarEmbarqueAlcancado(Position posicao) {
    final pontos = [...widget.carona.pontosEmbarque]
      ..sort((a, b) => a.ordem.compareTo(b.ordem));
    final pendentes = pontos.where(
      (ponto) => !_embarquesConcluidos.contains(_chavePonto(ponto)),
    );
    if (pendentes.isEmpty) return null;

    final proximo = pendentes.first;
    final chave = _chavePonto(proximo);
    final distancia = Geolocator.distanceBetween(
      posicao.latitude,
      posicao.longitude,
      proximo.latitude,
      proximo.longitude,
    );
    if (distancia > 30) {
      _pontoEmObservacao = null;
      _leiturasProximas = 0;
      return null;
    }

    if (_pontoEmObservacao == chave) {
      _leiturasProximas++;
    } else {
      _pontoEmObservacao = chave;
      _leiturasProximas = 1;
    }
    if (_leiturasProximas < 2) return null;

    _pontoEmObservacao = null;
    _leiturasProximas = 0;
    return proximo;
  }

  @override
  void initState() {
    super.initState();
    _acompanharMotorista();
  }

  Future<void> _acompanharMotorista() async {
    try {
      final stream = await LocalizacaoService().acompanharLocalizacao();
      if (!mounted) return;
      _localizacaoSubscription = stream.listen((posicao) {
        if (!mounted ||
            posicao.accuracy > 100 ||
            posicao.accuracy < 0 ||
            !posicao.accuracy.isFinite ||
            !posicao.latitude.isFinite ||
            !posicao.longitude.isFinite) {
          return;
        }
        final anterior = _localizacaoMotorista;
        final embarqueAlcancado = _detectarEmbarqueAlcancado(posicao);
        double? novaDirecao;
        if (posicao.speed >= 1 &&
            posicao.heading.isFinite &&
            posicao.heading >= 0) {
          novaDirecao = posicao.heading;
        } else if (anterior != null) {
          novaDirecao = Geolocator.bearingBetween(
            anterior.latitude,
            anterior.longitude,
            posicao.latitude,
            posicao.longitude,
          );
        }
        setState(() {
          _localizacaoMotorista = LatLng(posicao.latitude, posicao.longitude);
          if (novaDirecao != null) _direcaoMotorista = novaDirecao;
          if (embarqueAlcancado != null) {
            _embarquesConcluidos = {
              ..._embarquesConcluidos,
              _chavePonto(embarqueAlcancado),
            };
          }
        });
        unawaited(_enviarPosicaoSeNecessario(posicao, novaDirecao));
        if (embarqueAlcancado != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Embarque ${embarqueAlcancado.ordem} alcançado. Seguindo para o próximo ponto.',
              ),
            ),
          );
        }
      }, onError: (Object erro) => _mostrarErroLocalizacao(erro.toString()));
    } catch (erro) {
      _mostrarErroLocalizacao(erro.toString());
    }
  }

  Future<void> _enviarPosicaoSeNecessario(
    Position posicao,
    double? direcao,
  ) async {
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
        latitude: posicao.latitude,
        longitude: posicao.longitude,
        direcao: direcaoNormalizada,
        precisao: posicao.accuracy,
      );
    } finally {
      _enviandoPosicao = false;
    }
  }

  void _mostrarErroLocalizacao(String mensagem) {
    if (!mounted) return;
    final texto = mensagem.replaceFirst('Exception: ', '');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  void dispose() {
    _envioPosicaoAtivo = false;
    _localizacaoSubscription?.cancel();
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.directions_car, color: Colors.green, size: 24),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CORRIDA INICIADA',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Siga o percurso até o destino.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: MapaNavegacaoCarona(
                  carona: widget.carona,
                  localizacaoMotorista: _localizacaoMotorista,
                  direcaoMotorista: _direcaoMotorista,
                  embarquesConcluidos: _embarquesConcluidos,
                  onRotaCarregada: (resultado) {
                    if (mounted) setState(() => rota = resultado);
                  },
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
