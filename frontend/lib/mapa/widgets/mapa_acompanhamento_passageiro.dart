import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../models/carona.dart';
import '../../models/solicitacao_enviada.dart';
import '../services/rota_service.dart';
import '../utils/rota_mapa_utils.dart';
import 'mapa_percurso.dart';

class MapaAcompanhamentoPassageiro extends StatefulWidget {
  final SolicitacaoEnviada solicitacao;
  final LatLng? localizacaoMotorista;
  final double? direcaoMotorista;

  const MapaAcompanhamentoPassageiro({
    super.key,
    required this.solicitacao,
    required this.localizacaoMotorista,
    this.direcaoMotorista,
  });

  @override
  State<MapaAcompanhamentoPassageiro> createState() =>
      _MapaAcompanhamentoPassageiroState();
}

class _MapaAcompanhamentoPassageiroState
    extends State<MapaAcompanhamentoPassageiro> {
  final _service = RotaService();
  RotaResultado? _rota;
  String? _erro;
  bool _carregando = false;
  bool _recalculoPendente = false;
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
    if (recebeuPrimeiraLocalizacao || _motoristaSeMoveuParaRecalculo()) {
      _carregarRota();
    }
  }

  List<LatLng>? get _paradas {
    final motorista = widget.localizacaoMotorista;
    final embarqueLatitude = widget.solicitacao.embarqueLatitude;
    final embarqueLongitude = widget.solicitacao.embarqueLongitude;
    final destinoLatitude = widget.solicitacao.destinoLatitude;
    final destinoLongitude = widget.solicitacao.destinoLongitude;
    if (motorista == null ||
        !coordenadaValida(embarqueLatitude, embarqueLongitude) ||
        !coordenadaValida(destinoLatitude, destinoLongitude)) {
      return null;
    }

    return removerPontosConsecutivosProximos([
      motorista,
      LatLng(embarqueLatitude!, embarqueLongitude!),
      LatLng(destinoLatitude!, destinoLongitude!),
    ]);
  }

  bool _motoristaSeMoveuParaRecalculo() {
    final atual = widget.localizacaoMotorista;
    final ultima = _localizacaoUltimoCalculo;
    if (atual == null || ultima == null) return false;
    return const Distance().as(LengthUnit.Meter, ultima, atual) >=
        _distanciaParaRecalcular;
  }

  Future<void> _carregarRota() async {
    if (_carregando) {
      _recalculoPendente = true;
      return;
    }

    final paradas = _paradas;
    if (paradas == null || paradas.length < 2) return;
    _localizacaoUltimoCalculo = widget.localizacaoMotorista;
    setState(() {
      _erro = null;
      _carregando = true;
    });

    try {
      final rota = await _service
          .calcularRota(paradas)
          .timeout(const Duration(seconds: 40));
      if (!_rotaValida(rota)) throw const FormatException('Rota inválida');
      if (!mounted) return;
      setState(() {
        _rota = rota;
        _carregando = false;
      });
      _executarRecalculoPendente();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erro = 'Não foi possível atualizar o percurso.';
      });
      _executarRecalculoPendente();
    }
  }

  bool _rotaValida(RotaResultado rota) {
    return rota.pontos.length >= 2 &&
        rota.pontos.every(
          (ponto) => coordenadaValida(ponto.latitude, ponto.longitude),
        ) &&
        rota.distanciaMetros.isFinite &&
        rota.distanciaMetros >= 0 &&
        rota.duracaoSegundos.isFinite &&
        rota.duracaoSegundos >= 0;
  }

  void _executarRecalculoPendente() {
    if (!_recalculoPendente || !mounted) return;
    _recalculoPendente = false;
    _carregarRota();
  }

  Carona get _caronaMapa => Carona(
    id: widget.solicitacao.idCarona,
    origem: '',
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
        mensagem: _erro ?? 'Não foi possível mostrar o percurso.',
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
