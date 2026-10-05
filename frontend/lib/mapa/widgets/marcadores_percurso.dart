import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../config/app_colors.dart';
import '../../models/carona.dart';
import '../../models/ponto_embarque.dart';
import '../utils/rota_mapa_utils.dart';

class MarcadoresPercurso {
  final Carona carona;
  final List<LatLng> paradas;
  final bool navegacao;
  final bool mostrarMarcadorMotorista;
  final LatLng? localizacaoMotorista;
  final double direcaoMotorista;
  final Set<int> embarquesConcluidos;

  MarcadoresPercurso({
    required this.carona,
    required this.paradas,
    required this.navegacao,
    required this.mostrarMarcadorMotorista,
    required this.localizacaoMotorista,
    required this.direcaoMotorista,
    required this.embarquesConcluidos,
  });

  Marker _marcadorParada(int indice) {
    final origem = indice == 0;
    final destino = indice == paradas.length - 1;
    final cor = origem
        ? Colors.green.shade700
        : destino
        ? AppColors.primary
        : Colors.blue.shade700;
    return _marcadorCircular(
      ponto: paradas[indice],
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
    final concluido = embarquesConcluidos.contains(chavePontoEmbarque(ponto));
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

  List<Marker> construir() {
    if (!navegacao &&
        !(mostrarMarcadorMotorista && carona.pontosEmbarque.isNotEmpty)) {
      final marcadores = List.generate(paradas.length, _marcadorParada);
      if (mostrarMarcadorMotorista && localizacaoMotorista != null) {
        marcadores.removeAt(0);
        marcadores.add(_marcadorMotorista());
      }
      return marcadores;
    }
    return [
      ...carona.pontosEmbarque.map(_marcadorEmbarque),
      _marcadorCircular(
        ponto: LatLng(carona.destinoLatitude!, carona.destinoLongitude!),
        cor: AppColors.primary,
        titulo: 'Destino',
        rotacionar: true,
        child: const Icon(Icons.flag, size: 18, color: Colors.white),
      ),
      if (localizacaoMotorista != null) _marcadorMotorista(),
    ];
  }

  Marker _marcadorMotorista() {
    return Marker(
      point: localizacaoMotorista!,
      rotate: false,
      width: 46,
      height: 46,
      child: Tooltip(
        message: 'Motorista',
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue.shade700,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
          ),
          child: Transform.rotate(
            angle: direcaoMotorista * math.pi / 180,
            child: const Icon(Icons.navigation, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }
}
