import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class TesteMapa extends StatelessWidget {
  const TesteMapa({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teste OpenStreetMap'),
      ),
      body: FlutterMap(
        options: const MapOptions(
          initialCenter: LatLng(-21.2080, -50.4320),
          initialZoom: 14,
        ),
        children: [
          TileLayer(
            urlTemplate:
            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName:
            'com.unicarona.app',
          ),
        ],
      ),
    );
  }
}