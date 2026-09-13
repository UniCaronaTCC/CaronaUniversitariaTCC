import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../config/app_colors.dart';
import '../../models/carona.dart';
import '../../models/ponto_embarque.dart';
import '../services/rota_service.dart';
import '../utils/rota_mapa_utils.dart';

class MapaPercurso extends StatefulWidget {
  final Carona carona;
  final RotaResultado rota;
  final List<LatLng> paradas;
  final bool interativo;
  final bool navegacao;
  final LatLng? localizacaoMotorista;
  final double? direcaoMotorista;
  final Set<int> embarquesConcluidos;
  final bool atualizando;
  final String? erroAtualizacao;
  final VoidCallback? onTentarNovamente;

  const MapaPercurso({
    super.key,
    required this.carona,
    required this.rota,
    required this.paradas,
    this.interativo = false,
    this.navegacao = false,
    this.localizacaoMotorista,
    this.direcaoMotorista,
    this.embarquesConcluidos = const {},
    this.atualizando = false,
    this.erroAtualizacao,
    this.onTentarNovamente,
  });

  @override
  State<MapaPercurso> createState() => _MapaPercursoState();
}

class _MapaPercursoState extends State<MapaPercurso>
    with SingleTickerProviderStateMixin {
  final _mapController = MapController();
  late final AnimationController _animacaoCamera;
  LatLng? _cameraInicio;
  LatLng? _cameraDestino;
  double _rotacaoInicio = 0;
  double _rotacaoDestino = 0;

  @override
  void initState() {
    super.initState();
    _animacaoCamera = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    )..addListener(_atualizarAnimacaoCamera);
  }

  @override
  void didUpdateWidget(covariant MapaPercurso oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.navegacao &&
        widget.localizacaoMotorista != null &&
        widget.localizacaoMotorista != oldWidget.localizacaoMotorista) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _animarCamera(widget.localizacaoMotorista!, _direcaoNavegacao());
        }
      });
    }
  }

  @override
  void dispose() {
    _animacaoCamera.dispose();
    _mapController.dispose();
    super.dispose();
  }

  double _direcaoNavegacao() {
    final direcao = widget.direcaoMotorista;
    if (direcao != null && direcao.isFinite && direcao >= 0) return direcao;
    return direcaoInicial(widget.rota.pontos);
  }

  void _animarCamera(LatLng destino, double rotacao) {
    final camera = _mapController.camera;
    _cameraInicio = camera.center;
    _cameraDestino = destino;
    _rotacaoInicio = camera.rotation;
    final diferenca = (rotacao - camera.rotation + 540) % 360 - 180;
    _rotacaoDestino = camera.rotation + diferenca;
    _animacaoCamera.forward(from: 0);
  }

  void _atualizarAnimacaoCamera() {
    final inicio = _cameraInicio;
    final destino = _cameraDestino;
    if (inicio == null || destino == null) return;
    final progresso = Curves.easeOutCubic.transform(_animacaoCamera.value);
    final centro = LatLng(
      inicio.latitude + (destino.latitude - inicio.latitude) * progresso,
      inicio.longitude + (destino.longitude - inicio.longitude) * progresso,
    );
    final rotacao =
        _rotacaoInicio + (_rotacaoDestino - _rotacaoInicio) * progresso;
    _mapController.moveAndRotate(centro, 17.5, rotacao);
  }

  void _recentralizar() {
    if (widget.navegacao) {
      _mapController.moveAndRotate(
        widget.localizacaoMotorista ?? widget.rota.pontos.first,
        17.5,
        _direcaoNavegacao(),
      );
      return;
    }
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints([
          ...widget.rota.pontos,
          ...widget.paradas,
        ]),
        padding: const EdgeInsets.all(42),
        maxZoom: 16,
      ),
    );
  }

  Marker _marcadorParada(int indice) {
    final origem = indice == 0;
    final destino = indice == widget.paradas.length - 1;
    final cor = origem
        ? Colors.green.shade700
        : destino
        ? AppColors.primary
        : Colors.blue.shade700;
    return _marcadorCircular(
      ponto: widget.paradas[indice],
      cor: cor,
      titulo: origem
          ? 'Origem'
          : destino
          ? 'Destino'
          : 'Embarque $indice',
      child: origem || destino
          ? Icon(
              origem ? Icons.trip_origin : Icons.flag,
              size: 18,
              color: Colors.white,
            )
          : Text(
              '$indice',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }

  Marker _marcadorEmbarque(PontoEmbarque ponto) {
    final concluido = widget.embarquesConcluidos.contains(
      chavePontoEmbarque(ponto),
    );
    return _marcadorCircular(
      ponto: LatLng(ponto.latitude, ponto.longitude),
      cor: concluido ? Colors.green.shade700 : Colors.blue.shade700,
      titulo: concluido
          ? 'Embarque ${ponto.ordem} alcançado'
          : 'Embarque ${ponto.ordem}',
      rotacionar: true,
      child: concluido
          ? const Icon(Icons.check, size: 20, color: Colors.white)
          : Text(
              '${ponto.ordem}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }

  Marker _marcadorCircular({
    required LatLng ponto,
    required Color cor,
    required String titulo,
    required Widget child,
    bool rotacionar = false,
  }) {
    return Marker(
      point: ponto,
      rotate: rotacionar,
      width: 36,
      height: 36,
      child: Tooltip(
        message: titulo,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: cor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
          ),
          child: child,
        ),
      ),
    );
  }

  List<Marker> _marcadores() {
    if (!widget.navegacao) {
      return List.generate(widget.paradas.length, _marcadorParada);
    }
    return [
      ...widget.carona.pontosEmbarque.map(_marcadorEmbarque),
      _marcadorCircular(
        ponto: LatLng(
          widget.carona.destinoLatitude!,
          widget.carona.destinoLongitude!,
        ),
        cor: AppColors.primary,
        titulo: 'Destino',
        rotacionar: true,
        child: const Icon(Icons.flag, size: 18, color: Colors.white),
      ),
      if (widget.localizacaoMotorista != null)
        Marker(
          point: widget.localizacaoMotorista!,
          rotate: true,
          width: 46,
          height: 46,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 6),
              ],
            ),
            child: const Icon(Icons.navigation, color: Colors.white, size: 24),
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter:
                widget.localizacaoMotorista ?? widget.rota.pontos.first,
            initialZoom: widget.navegacao ? 17.5 : 13,
            initialRotation: widget.navegacao ? _direcaoNavegacao() : 0,
            initialCameraFit: widget.navegacao
                ? null
                : CameraFit.bounds(
                    bounds: LatLngBounds.fromPoints([
                      ...widget.rota.pontos,
                      ...widget.paradas,
                    ]),
                    padding: const EdgeInsets.all(36),
                    maxZoom: 16,
                  ),
            interactionOptions: InteractionOptions(
              flags: widget.interativo
                  ? InteractiveFlag.all
                  : InteractiveFlag.none,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.unicarona.app',
            ),
            PolylineLayer(
              polylines: [
                Polyline(
                  points: widget.rota.pontos,
                  color: Colors.blue.shade700,
                  strokeWidth: 5,
                  borderColor: Colors.white,
                  borderStrokeWidth: 2,
                ),
              ],
            ),
            MarkerLayer(markers: _marcadores()),
            const SimpleAttributionWidget(
              source: Text('OpenStreetMap contributors'),
            ),
          ],
        ),
        if (widget.atualizando) const _AvisoAtualizando(),
        if (widget.erroAtualizacao != null)
          _AvisoErro(onTentarNovamente: widget.onTentarNovamente),
        if (widget.interativo)
          Positioned(
            right: 12,
            bottom: 42,
            child: FloatingActionButton.small(
              heroTag: null,
              onPressed: _recentralizar,
              tooltip: widget.navegacao
                  ? 'Voltar para a navegação'
                  : 'Mostrar percurso completo',
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              child: Icon(
                widget.navegacao ? Icons.navigation : Icons.center_focus_strong,
              ),
            ),
          ),
      ],
    );
  }
}

class _AvisoAtualizando extends StatelessWidget {
  const _AvisoAtualizando();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 12,
      left: 12,
      child: Material(
        color: Colors.white,
        elevation: 2,
        borderRadius: BorderRadius.circular(20),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text('Atualizando rota...', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvisoErro extends StatelessWidget {
  final VoidCallback? onTentarNovamente;

  const _AvisoErro({this.onTentarNovamente});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 12,
      left: 12,
      right: 12,
      child: Material(
        color: Colors.white,
        elevation: 2,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Não foi possível atualizar a rota.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              TextButton(
                onPressed: onTentarNovamente,
                child: const Text('TENTAR'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
