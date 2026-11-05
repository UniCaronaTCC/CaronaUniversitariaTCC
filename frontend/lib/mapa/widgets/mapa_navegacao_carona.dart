import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../config/app_colors.dart';
import '../../widgets/visual_buscaeu.dart';
import '../../models/carona.dart';
import '../../models/ponto_embarque.dart';
import '../services/rota_service.dart';
import '../utils/rota_mapa_utils.dart';
import 'mapa_percurso.dart';

class MapaNavegacaoCarona extends StatefulWidget {
  final Carona carona;
  final List<PontoEmbarque>? pontosPercurso;
  final LatLng? localizacaoMotorista;
  final double? direcaoMotorista;
  final double? precisaoMotorista;
  final RotaService? rotaService;
  final String? erroLocalizacao;
  final Set<int> embarquesConcluidos;
  final ValueChanged<RotaResultado>? onRotaCarregada;

  const MapaNavegacaoCarona({
    super.key,
    required this.carona,
    this.pontosPercurso,
    required this.localizacaoMotorista,
    this.direcaoMotorista,
    this.precisaoMotorista,
    this.rotaService,
    this.erroLocalizacao,
    this.embarquesConcluidos = const {},
    this.onRotaCarregada,
  });

  @override
  State<MapaNavegacaoCarona> createState() => _MapaNavegacaoCaronaState();
}

class _MapaNavegacaoCaronaState extends State<MapaNavegacaoCarona> {
  late final _service = widget.rotaService ?? RotaService();
  List<LatLng>? _paradas;
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
    _atualizarParadas();
    _carregarRota();
  }

  @override
  void didUpdateWidget(covariant MapaNavegacaoCarona oldWidget) {
    super.didUpdateWidget(oldWidget);
    final recebeuPrimeiraLocalizacao =
        oldWidget.localizacaoMotorista == null &&
        widget.localizacaoMotorista != null;
    final embarquesAlterados =
        oldWidget.embarquesConcluidos.length !=
            widget.embarquesConcluidos.length ||
        !oldWidget.embarquesConcluidos.containsAll(widget.embarquesConcluidos);
    final paradasAlteradas =
        _assinatura(oldWidget.pontosPercurso) !=
        _assinatura(widget.pontosPercurso);
    if (paradasAlteradas) _rota = null;
    final motoristaSeMoveu = _motoristaSeMoveuParaRecalculo();
    if (oldWidget.carona != widget.carona ||
        recebeuPrimeiraLocalizacao ||
        embarquesAlterados ||
        paradasAlteradas ||
        motoristaSeMoveu) {
      _atualizarParadas();
      _carregarRota();
    }
  }

  String _assinatura(List<PontoEmbarque>? pontos) =>
      pontos
          ?.map((p) => '${p.id}:${p.ordem}:${p.latitude}:${p.longitude}')
          .join('|') ??
      '';

  Carona get _caronaPercurso => widget.pontosPercurso == null
      ? widget.carona
      : widget.carona.comPontosDoPercurso(widget.pontosPercurso!);

  bool _motoristaSeMoveuParaRecalculo() {
    final atual = widget.localizacaoMotorista;
    final ultima = _localizacaoUltimoCalculo;
    if (atual == null || ultima == null) return false;
    return const Distance().as(LengthUnit.Meter, ultima, atual) >=
        _distanciaParaRecalcular;
  }

  void _atualizarParadas() {
    final localizacao = widget.localizacaoMotorista;
    _paradas = localizacao == null
        ? null
        : paradasDaNavegacao(
            _caronaPercurso,
            localizacao,
            widget.embarquesConcluidos,
          );
  }

  Future<void> _carregarRota() async {
    if (_carregando || _recalculoAgendado != null) {
      _recalculoPendente = true;
      return;
    }

    _atualizarParadas();
    final paradas = _paradas;
    setState(() {
      _erro = null;
      _carregando = paradas != null;
    });
    if (paradas == null) return;
    _iniciarIntervalo();
    _localizacaoUltimoCalculo = widget.localizacaoMotorista;

    try {
      final assinatura = _assinatura(widget.pontosPercurso);
      final rota = await _service.calcularRota(paradas);
      if (!mounted) return;
      if (assinatura != _assinatura(widget.pontosPercurso)) {
        setState(() => _carregando = false);
        _recalculoPendente = true;
        _carregarRota();
        return;
      }
      setState(() {
        _rota = rota;
        _carregando = false;
      });
      widget.onRotaCarregada?.call(rota);
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
        _erro = 'Não foi possível carregar a rota. Tente novamente.';
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

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: VisualBuscaEu.borda),
      ),
      child: _conteudo(),
    );
  }

  Widget _conteudo() {
    if (widget.localizacaoMotorista == null) {
      if (widget.erroLocalizacao != null) {
        return _EstadoErro(mensagem: widget.erroLocalizacao!);
      }
      return const _EstadoCarregando(mensagem: 'Obtendo sua localização...');
    }
    if (_carregando && _rota == null) {
      return const _EstadoCarregando(
        mensagem: 'Calculando o percurso pelas ruas...',
      );
    }
    if (_paradas == null || _rota == null) {
      return _EstadoErro(
        mensagem:
            _erro ??
            'Esta carona não possui as coordenadas necessárias para mostrar o percurso.',
        onTentarNovamente: _erro == null ? null : _carregarRota,
      );
    }
    return MapaPercurso(
      carona: _caronaPercurso,
      rota: _rota!,
      paradas: _paradas!,
      interativo: true,
      navegacao: true,
      localizacaoMotorista: widget.localizacaoMotorista,
      direcaoMotorista: widget.direcaoMotorista,
      precisaoMotorista: widget.precisaoMotorista,
      embarquesConcluidos: widget.embarquesConcluidos,
      atualizando: _carregando,
      erroAtualizacao: _erro,
      onTentarNovamente: _carregarRota,
    );
  }
}

class _EstadoCarregando extends StatelessWidget {
  final String mensagem;

  const _EstadoCarregando({required this.mensagem});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 14),
            Text(mensagem),
          ],
        ),
      ),
    );
  }
}

class _EstadoErro extends StatelessWidget {
  final String mensagem;
  final VoidCallback? onTentarNovamente;

  const _EstadoErro({required this.mensagem, this.onTentarNovamente});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_outlined, color: Colors.black45, size: 36),
            const SizedBox(height: 10),
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
