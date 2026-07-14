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
        options: const MapOptions(
          // Localização fixa apenas para teste.
          // Assim que o GPS responder, o mapa será centralizado
          // automaticamente na posição do usuário.
          initialCenter: LatLng(-21.2080, -50.4320),
          initialZoom: 14,
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
        ],
      ),
    );
  }
}