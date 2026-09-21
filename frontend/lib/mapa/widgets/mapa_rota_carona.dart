import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../config/app_colors.dart';
import '../../models/carona.dart';
import '../services/rota_service.dart';

class MapaRotaCarona extends StatefulWidget {
  final Carona carona;

  const MapaRotaCarona({super.key, required this.carona});

  @override
  State<MapaRotaCarona> createState() => _MapaRotaCaronaState();
}

class _MapaRotaCaronaState extends State<MapaRotaCarona> {
  final _service = RotaService();
  List<LatLng>? _paradas;
  RotaResultado? _rota;
  String? _erro;
  bool _carregando = false;
  int _requisicao = 0;

  @override
  void initState() {
    super.initState();
    _paradas = _montarParadas();
    _carregarRota();
  }

  @override
  void didUpdateWidget(covariant MapaRotaCarona oldWidget) {
    super.didUpdateWidget(oldWidget);
    final novasParadas = _montarParadas();
    if (!listEquals(_paradas, novasParadas)) {
      _paradas = novasParadas;
      _carregarRota();
    }
  }

  bool _coordenadaValida(double? latitude, double? longitude) {
    return latitude != null &&
        longitude != null &&
        latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  List<LatLng>? _montarParadas() {
    final carona = widget.carona;
    final pontos = [...carona.pontosEmbarque]
      ..sort((a, b) => a.ordem.compareTo(b.ordem));
    if (!_coordenadaValida(carona.origemLatitude, carona.origemLongitude) ||
        !_coordenadaValida(carona.destinoLatitude, carona.destinoLongitude) ||
        pontos.any((p) => !_coordenadaValida(p.latitude, p.longitude))) {
      return null;
    }
    return [
      LatLng(carona.origemLatitude!, carona.origemLongitude!),
      ...pontos.map((p) => LatLng(p.latitude, p.longitude)),
      LatLng(carona.destinoLatitude!, carona.destinoLongitude!),
    ];
  }

  Future<void> _carregarRota() async {
    final requisicao = ++_requisicao;
    final paradas = _paradas;
    setState(() {
      _rota = null;
      _erro = null;
      _carregando = paradas != null;
    });
    if (paradas == null) return;

    try {
      final rota = await _service
          .calcularRota(paradas)
          .timeout(const Duration(seconds: 30));
      if (rota.pontos.length < 2 ||
          rota.pontos.any((p) => !_coordenadaValida(p.latitude, p.longitude)) ||
          !rota.distanciaMetros.isFinite ||
          rota.distanciaMetros < 0 ||
          !rota.duracaoSegundos.isFinite ||
          rota.duracaoSegundos < 0) {
        throw const FormatException('Rota inválida');
      }
      if (!mounted || requisicao != _requisicao) return;
      setState(() {
        _rota = rota;
        _carregando = false;
      });
    } catch (_) {
      if (!mounted || requisicao != _requisicao) return;
      setState(() {
        _carregando = false;
        _erro = 'Não foi possível carregar a rota. Tente novamente.';
      });
    }
  }

  String _duracao(double segundos) {
    final minutos = (segundos / 60).ceil();
    if (minutos < 1) return 'Menos de 1 min';
    if (minutos < 60) return '$minutos min';
    final restante = minutos % 60;
    return '${minutos ~/ 60} h${restante == 0 ? '' : ' $restante min'}';
  }

  Marker _marcador(int indice) {
    final origem = indice == 0;
    final destino = indice == _paradas!.length - 1;
    final cor = origem
        ? Colors.green.shade700
        : destino
        ? AppColors.primary
        : Colors.blue.shade700;
    final titulo = origem
        ? 'Origem'
        : destino
        ? 'Destino'
        : 'Embarque $indice';
    return Marker(
      point: _paradas![indice],
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rota = _rota;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.route, color: AppColors.primary),
                SizedBox(width: 10),
                Text(
                  'Percurso da carona',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          if (_carregando)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Calculando o percurso pelas ruas...'),
                ],
              ),
            )
          else if (_paradas == null || _erro != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  const Icon(
                    Icons.map_outlined,
                    color: Colors.black45,
                    size: 36,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _erro ??
                        'Esta carona não possui todas as coordenadas '
                            'necessárias para mostrar o percurso.',
                    textAlign: TextAlign.center,
                  ),
                  if (_erro != null)
                    TextButton.icon(
                      onPressed: _carregarRota,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                    ),
                ],
              ),
            )
          else if (rota != null) ...[
            SizedBox(
              height: 260,
              child: FlutterMap(
                key: ValueKey(_requisicao),
                options: MapOptions(
                  initialCameraFit: CameraFit.bounds(
                    bounds: LatLngBounds.fromPoints([
                      ...rota.pontos,
                      ..._paradas!,
                    ]),
                    padding: const EdgeInsets.all(36),
                    maxZoom: 16,
                  ),
                  // Mantém a rolagem da tela fluida neste mapa de preview.
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.unicarona.app',
                  ),
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: rota.pontos,
                        color: Colors.blue.shade700,
                        strokeWidth: 5,
                        borderColor: Colors.white,
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: List.generate(_paradas!.length, _marcador),
                  ),
                  const SimpleAttributionWidget(
                    source: Text('OpenStreetMap contributors'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 20,
                    runSpacing: 8,
                    children: [
                      Text(
                        '${(rota.distanciaMetros / 1000).toStringAsFixed(1).replaceAll('.', ',')} km',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _duracao(rota.duracaoSegundos),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Distância total • Tempo estimado',
                    style: TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      Text(
                        '● Origem',
                        style: TextStyle(color: Colors.green.shade700),
                      ),
                      if (_paradas!.length > 2)
                        Text(
                          '● Embarques numerados',
                          style: TextStyle(color: Colors.blue.shade700),
                        ),
                      const Text(
                        '⚑ Destino',
                        style: TextStyle(color: AppColors.primary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
