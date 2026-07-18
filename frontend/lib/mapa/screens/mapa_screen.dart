import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/localizacao_service.dart';

class TesteMapa extends StatefulWidget {
  const TesteMapa({super.key});

  @override
  State<TesteMapa> createState() => _TesteMapaState();
}

class _TesteMapaState extends State<TesteMapa> {
  // Serviço responsável por obter a localização do usuário.
  final LocalizacaoService _localizacaoService = LocalizacaoService();

  // Controlador responsável por controlar o mapa.
  final MapController _mapController = MapController();

  // Armazena a localização atual do usuário.
  LatLng? _localizacaoAtual;
// agr guarda a localizacão do ponto de encontro
  LatLng? _pontoEncontro;

  // o "_" na variavel acima significa q e uma variavel privada a esse arquivo

  @override
  void initState() {
    super.initState();

    // Obtém a localização assim que a tela é aberta.
    _obterLocalizacao();
  }

  /// Obtém a localização atual do usuário e centraliza o mapa.
  Future<void> _obterLocalizacao() async {
    try {
      final posicao = await _localizacaoService.obterLocalizacaoAtual();

      debugPrint('==============================');
      debugPrint('Latitude: ${posicao.latitude}');
      debugPrint('Longitude: ${posicao.longitude}');
      debugPrint('==============================');

      // Salva a localização atual.
      // Atualiza a interface com a localização do usuário.
      setState(() {
        _localizacaoAtual = LatLng(
          posicao.latitude,
          posicao.longitude,
        );
      });

// Move o mapa para a localização do usuário.
      _mapController.move(_localizacaoAtual!, 16);
    } catch (e) {
      debugPrint('Erro ao obter localização: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teste OpenStreetMap'),
      ),
      body: FlutterMap(
        // Controlador do mapa.
        mapController: _mapController,
        options: MapOptions(
          // Localização fixa apenas para teste.
          initialCenter: const LatLng(-21.2080, -50.4320),
          initialZoom: 14,

          // Executado quando o usuário toca no mapa.
          onTap: (tapPosition, point) {
            setState(() {
              _pontoEncontro = point;
            });
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.unicarona.app',
          ),

          // Exibe o marcador da localização do usuário.
          if (_localizacaoAtual != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: _localizacaoAtual!,
                  width: 50,
                  height: 50,
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.red,
                    size: 40,
                  ),
                ),
              ],
            ),
          // Exibe o marcador do ponto de encontro escolhido pelo usuário.
          if (_pontoEncontro != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: _pontoEncontro!,
                  width: 50,
                  height: 50,
                  child: const Icon(
                    Icons.place,
                    color: Colors.blue,
                    size: 40,
                  ),
                ),
              ],
            ),
        ],
      ),
      bottomNavigationBar: _pontoEncontro == null
          ? null
          : Container(
        padding: const EdgeInsets.all(16),
        color: Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ponto de encontro selecionado',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Latitude: ${_pontoEncontro!.latitude.toStringAsFixed(6)}',
            ),

            Text(
              'Longitude: ${_pontoEncontro!.longitude.toStringAsFixed(6)}',
            ),
          ],
        ),
      ),
    );
  }
}