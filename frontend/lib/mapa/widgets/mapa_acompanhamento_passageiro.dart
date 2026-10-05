import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../models/carona.dart';
import '../../models/ponto_embarque.dart';
import '../../models/solicitacao_enviada.dart';
import '../services/rota_service.dart';
import '../utils/rota_mapa_utils.dart';
import 'mapa_percurso.dart';

class MapaAcompanhamentoPassageiro extends StatefulWidget {
  final SolicitacaoEnviada solicitacao;
  final LatLng? localizacaoMotorista;
  final double? direcaoMotorista;
  final RotaService? rotaService;
  final List<PontoEmbarque>? pontosPercurso;

  const MapaAcompanhamentoPassageiro({
    super.key,
    required this.solicitacao,
    required this.localizacaoMotorista,
    this.direcaoMotorista,
    this.rotaService,
    this.pontosPercurso,
  });

  @override
  State<MapaAcompanhamentoPassageiro> createState() =>
      _MapaAcompanhamentoPassageiroState();
}

class _MapaAcompanhamentoPassageiroState
    extends State<MapaAcompanhamentoPassageiro> {
  late final _service = widget.rotaService ?? RotaService();
  RotaResultado? _rota;
  String? _erro;
  bool _carregando = false;
  bool _recalculoPendente = false;
  Timer? _recalculoAgendado;
  LatLng? _localizacaoUltimoCalculo;

  static const _distanciaParaRecalcular = 50.0;

  @override
  void initState() {
    super.initState();
    _carregarRota();
  }

  @override
  void didUpdateWidget(covariant MapaAcompanhamentoPassageiro oldWidget) {
    super.didUpdateWidget(oldWidget);
    final recebeuPrimeiraLocalizacao =
        oldWidget.localizacaoMotorista == null &&
        widget.localizacaoMotorista != null;
    if (oldWidget.solicitacao != widget.solicitacao ||
        _assinatura(oldWidget.pontosPercurso) !=
            _assinatura(widget.pontosPercurso) ||
        recebeuPrimeiraLocalizacao ||
        _motoristaSeMoveuParaRecalculo()) {
      _carregarRota();
    }
  }

  List<LatLng>? get _paradas {
    final motorista = widget.localizacaoMotorista;
    final pontos = widget.pontosPercurso;
    final destinoLatitude = widget.solicitacao.destinoLatitude;
    final destinoLongitude = widget.solicitacao.destinoLongitude;
    if (motorista == null ||
        pontos == null ||
        !coordenadaValida(destinoLatitude, destinoLongitude)) {
      return null;
    }
    return removerPontosConsecutivosProximos([
      motorista,
      ...pontos
          .where((p) => p.percorridoEm == null)
          .map((p) => LatLng(p.latitude, p.longitude)),
      LatLng(destinoLatitude!, destinoLongitude!),
    ]);
  }

  String _assinatura(List<PontoEmbarque>? pontos) => pontos == null
      ? 'aguardando'
      : pontos
            .map(
              (p) => [
                p.id,
                p.ordem,
                p.latitude,
                p.longitude,
                p.percorridoEm,
              ].join(':'),
            )
            .join('|');

  bool _motoristaSeMoveuParaRecalculo() {
    final atual = widget.localizacaoMotorista;
    final ultima = _localizacaoUltimoCalculo;
    if (atual == null || ultima == null) return false;
    return const Distance().as(LengthUnit.Meter, ultima, atual) >=
        _distanciaParaRecalcular;
  }

  Future<void> _carregarRota() async {
    if (_carregando || _recalculoAgendado != null) {
      _recalculoPendente = true;
      return;
    }

    final paradas = _paradas;
    if (paradas == null || paradas.isEmpty) return;
    _iniciarIntervalo();
    _localizacaoUltimoCalculo = widget.localizacaoMotorista;
    setState(() {
      _erro = null;
      _carregando = true;
    });

    try {
      final rota = await _service.calcularRota(paradas);
      if (!mounted) return;
      setState(() {
        _rota = rota;
        _carregando = false;
      });
      if (_recalculoPendente || _motoristaSeMoveuParaRecalculo()) {
        _recalculoPendente = false;
        _carregarRota();
      }
    } catch (_) {
      if (!mounted) return;
      _iniciarIntervalo();
      _recalculoPendente = false;
      setState(() {
        _carregando = false;
        _erro = 'Não foi possível atualizar o percurso.';
      });
    }
  }

  void _iniciarIntervalo() {
    _recalculoAgendado?.cancel();
    _recalculoAgendado = Timer(const Duration(seconds: 15), () {
      _recalculoAgendado = null;
      if (mounted && _recalculoPendente && !_carregando) {
        _recalculoPendente = false;
        _carregarRota();
      }
    });
  }

  @override
  void dispose() {
    _recalculoAgendado?.cancel();
    super.dispose();
  }

  Carona get _caronaMapa => Carona(
    id: widget.solicitacao.idCarona,
    origem: '',
    pontosEmbarque: widget.pontosPercurso ?? [],
    destino: widget.solicitacao.destino,
    destinoLatitude: widget.solicitacao.destinoLatitude,
    destinoLongitude: widget.solicitacao.destinoLongitude,
    dataInicio: widget.solicitacao.dataInicio,
    horario: widget.solicitacao.horario,
    vagas: 0,
    valor: widget.solicitacao.valor,
    recorrente: false,
    diasSemana: const [],
    motorista: widget.solicitacao.motorista,
  );

  @override
  Widget build(BuildContext context) {
    final paradas = _paradas;
    if (widget.localizacaoMotorista == null) {
      return const _EstadoMapa(
        icone: Icons.location_searching_outlined,
        mensagem: 'Aguardando a localização do motorista...',
        carregando: true,
      );
    }
    if (_carregando && _rota == null) {
      return const _EstadoMapa(
        icone: Icons.route_outlined,
        mensagem: 'Atualizando o percurso...',
        carregando: true,
      );
    }
    if (paradas == null || _rota == null) {
      return _EstadoMapa(
        icone: Icons.map_outlined,
        mensagem:
            _erro ??
            (widget.pontosPercurso == null
                ? 'Aguardando os pontos do percurso...'
                : 'Não foi possível mostrar o percurso.'),
        onTentarNovamente: _erro == null ? null : _carregarRota,
      );
    }

    return MapaPercurso(
      carona: _caronaMapa,
      rota: _rota!,
      paradas: paradas,
      interativo: true,
      localizacaoMotorista: widget.localizacaoMotorista,
      direcaoMotorista: widget.direcaoMotorista,
      mostrarMarcadorMotorista: true,
      embarquesConcluidos: (widget.pontosPercurso ?? [])
          .where((p) => p.percorridoEm != null)
          .map((p) => p.id!)
          .toSet(),
      atualizando: _carregando,
      erroAtualizacao: _erro,
      onTentarNovamente: _carregarRota,
    );
  }
}

class _EstadoMapa extends StatelessWidget {
  final IconData icone;
  final String mensagem;
  final bool carregando;
  final VoidCallback? onTentarNovamente;

  const _EstadoMapa({
    required this.icone,
    required this.mensagem,
    this.carregando = false,
    this.onTentarNovamente,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (carregando)
              const CircularProgressIndicator()
            else
              Icon(icone, color: Colors.black45, size: 40),
            const SizedBox(height: 14),
            Text(mensagem, textAlign: TextAlign.center),
            if (onTentarNovamente != null)
              TextButton.icon(
                onPressed: onTentarNovamente,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
          ],
        ),
      ),
    );
  }
}
