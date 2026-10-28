import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Ajuste apenas visual, limitado pela precisão estimada e a 20 m.
/// Não deve alimentar recálculo de rota nem registro de passagem por pontos.
LatLng posicaoVisualNoPercurso({
  required LatLng posicao,
  required List<LatLng> percurso,
  required double? precisao,
  required double? direcao,
}) {
  if (percurso.length < 2 ||
      !_valida(posicao) ||
      precisao == null ||
      !precisao.isFinite ||
      precisao < 0 ||
      precisao > 40 ||
      direcao == null ||
      !direcao.isFinite ||
      direcao < 0) {
    return posicao;
  }
  final limite = precisao.clamp(3, 20).toDouble();
  const metrosPorGrau = math.pi * 6371000 / 180;
  final escalaLongitude =
      metrosPorGrau * math.cos(posicao.latitude * math.pi / 180);
  final candidatos = <({LatLng ponto, double distancia, double direcao})>[];
  for (var indice = 1; indice < percurso.length; indice++) {
    final inicio = percurso[indice - 1];
    final fim = percurso[indice];
    if (!_valida(inicio) || !_valida(fim)) continue;
    final x = (inicio.longitude - posicao.longitude) * escalaLongitude;
    final y = (inicio.latitude - posicao.latitude) * metrosPorGrau;
    final dx = (fim.longitude - inicio.longitude) * escalaLongitude;
    final dy = (fim.latitude - inicio.latitude) * metrosPorGrau;
    final comprimentoQuadrado = dx * dx + dy * dy;
    if (comprimentoQuadrado < 1) continue;
    final fracao = (-(x * dx + y * dy) / comprimentoQuadrado).clamp(0.0, 1.0);
    final distancia = math.sqrt(
      math.pow(x + fracao * dx, 2) + math.pow(y + fracao * dy, 2),
    );
    if (distancia > limite) continue;
    candidatos.add((
      ponto: LatLng(
        inicio.latitude + fracao * (fim.latitude - inicio.latitude),
        inicio.longitude + fracao * (fim.longitude - inicio.longitude),
      ),
      distancia: distancia,
      direcao: (math.atan2(dx, dy) * 180 / math.pi + 360) % 360,
    ));
  }
  if (candidatos.isEmpty) return posicao;
  candidatos.sort((a, b) => a.distancia.compareTo(b.distancia));
  final maisProximo = candidatos.first;
  if (_diferencaDirecao(maisProximo.direcao, direcao) > 35) return posicao;
  // Em traçados paralelos/retornos próximos, não escolhe um ramo por palpite.
  for (final outro in candidatos.skip(1)) {
    if (outro.distancia - maisProximo.distancia > 5) break;
    if (_diferencaDirecao(outro.direcao, direcao) <= 35 &&
        const Distance().as(LengthUnit.Meter, maisProximo.ponto, outro.ponto) >
            8) {
      return posicao;
    }
  }
  return maisProximo.ponto;
}

bool _valida(LatLng ponto) =>
    ponto.latitude.isFinite &&
    ponto.longitude.isFinite &&
    ponto.latitude.abs() <= 90 &&
    ponto.longitude.abs() <= 180;

double _diferencaDirecao(double primeira, double segunda) =>
    ((primeira - segunda + 540) % 360 - 180).abs();
