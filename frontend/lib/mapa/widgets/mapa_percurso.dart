import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../config/app_colors.dart';
import '../../models/carona.dart';
import 'marcadores_percurso.dart';
import 'avisos_rota.dart';
import '../services/rota_service.dart';
import '../utils/rota_mapa_utils.dart';

class MapaPercurso extends StatefulWidget {
  final Carona carona;
  final RotaResultado rota;
  final List<LatLng> paradas;
  final bool interativo;
  final bool navegacao;
  final bool mostrarMarcadorMotorista;
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
    this.mostrarMarcadorMotorista = false,
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
  bool _seguirMotorista = true;
  bool _mapaPronto = false;
  LatLng? _posicaoExibida;
  double _direcaoExibida = 0;
  double _direcaoInicio = 0;
  double _direcaoDestino = 0;
  LatLng? _cameraInicio;
  LatLng? _cameraDestino;
  double _rotacaoInicio = 0;
  double _rotacaoDestino = 0;

  @override
  void initState() {
    super.initState();
    _posicaoExibida = widget.localizacaoMotorista;
    _direcaoExibida = _direcaoNavegacao();
    _animacaoCamera = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    )..addListener(_atualizarAnimacaoCamera);
  }

  @override
  void didUpdateWidget(covariant MapaPercurso oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.localizacaoMotorista != null &&
        (widget.localizacaoMotorista != oldWidget.localizacaoMotorista ||
            widget.direcaoMotorista != oldWidget.direcaoMotorista)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _mapaPronto) {
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
    if (direcao != null && direcao.isFinite && direcao >= 0) {
      return direcao % 360;
    }
    return direcaoInicial(widget.rota.pontos);
  }

  void _animarCamera(LatLng destino, double rotacao) {
    final camera = _mapController.camera;
    _cameraInicio = _posicaoExibida ?? destino;
    _direcaoInicio = _direcaoExibida;
    _direcaoDestino =
        _direcaoInicio + (rotacao - _direcaoInicio + 540) % 360 - 180;
    _cameraDestino = destino;
    _rotacaoInicio = camera.rotation;
    final diferenca = (-rotacao - camera.rotation + 540) % 360 - 180;
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
    _posicaoExibida = centro;
    _direcaoExibida =
        _direcaoInicio + (_direcaoDestino - _direcaoInicio) * progresso;
    if (widget.navegacao && _seguirMotorista && _mapaPronto) {
      _mapController.moveAndRotate(centro, _mapController.camera.zoom, rotacao);
    }
  }

  void _recentralizar() {
    setState(() => _seguirMotorista = true);
    if (widget.navegacao) {
      _animacaoCamera.stop();
      _posicaoExibida = widget.localizacaoMotorista;
      _direcaoExibida = _direcaoNavegacao();
      _mapController.moveAndRotate(
        widget.localizacaoMotorista ?? widget.rota.pontos.first,
        17.5,
        -_direcaoNavegacao(),
      );
      return;
    }
    _mapController.rotate(0);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints([
          ...widget.rota.pontos,
          ...widget.paradas,
          if (widget.localizacaoMotorista != null) widget.localizacaoMotorista!,
        ]),
        padding: const EdgeInsets.all(42),
        maxZoom: 16,
      ),
    );
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
            initialRotation: widget.navegacao ? -_direcaoNavegacao() : 0,
            onMapReady: () => _mapaPronto = true,
            onPositionChanged: (_, gesto) {
              if (gesto) _seguirMotorista = false;
            },
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
            AnimatedBuilder(
              animation: _animacaoCamera,
              builder: (_, _) => MarkerLayer(
                markers: MarcadoresPercurso(
                  carona: widget.carona,
                  paradas: widget.paradas,
                  navegacao: widget.navegacao,
                  mostrarMarcadorMotorista: widget.mostrarMarcadorMotorista,
                  localizacaoMotorista: _posicaoExibida,
                  direcaoMotorista: _direcaoExibida,
                  embarquesConcluidos: widget.embarquesConcluidos,
                ).construir(),
              ),
            ),
            const SimpleAttributionWidget(
              source: Text('OpenStreetMap contributors'),
            ),
          ],
        ),
        if (widget.atualizando) const AvisoAtualizandoRota(),
        if (widget.erroAtualizacao != null)
          AvisoErroRota(onTentarNovamente: widget.onTentarNovamente),
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
