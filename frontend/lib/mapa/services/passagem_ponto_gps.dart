import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

bool posicaoPrecisaParaPonto(Position posicao) =>
    posicao.latitude.isFinite &&
    posicao.longitude.isFinite &&
    posicao.latitude.abs() <= 90 &&
    posicao.longitude.abs() <= 180 &&
    posicao.accuracy.isFinite &&
    posicao.accuracy >= 0 &&
    posicao.accuracy <= 30;

/// Estima uma passagem curta entre amostras; não confirma embarque.
bool passouPeloPonto({
  required Position anterior,
  required Position atual,
  required double latitude,
  required double longitude,
}) {
  if (!posicaoPrecisaParaPonto(anterior) ||
      !posicaoPrecisaParaPonto(atual) ||
      !latitude.isFinite ||
      !longitude.isFinite ||
      latitude.abs() > 90 ||
      longitude.abs() > 180) {
    return false;
  }
  final intervalo = atual.timestamp.difference(anterior.timestamp);
  if (intervalo <= Duration.zero || intervalo > const Duration(seconds: 10)) {
    return false;
  }
  final metros = Geolocator.distanceBetween(
    anterior.latitude,
    anterior.longitude,
    atual.latitude,
    atual.longitude,
  );
  final segundos = intervalo.inMicroseconds / Duration.microsecondsPerSecond;
  // Evita ligar amostras distantes, saltos e longos períodos sem GPS.
  if (metros > 200 || metros > 55 * segundos || metros < 2) return false;

  // Projeção local em metros, adequada ao segmento curto de até 200 m.
  const metrosPorGrau = math.pi * 6371000 / 180;
  final longitudeEmMetros = metrosPorGrau * math.cos(latitude * math.pi / 180);
  final x1 = (anterior.longitude - longitude) * longitudeEmMetros;
  final y1 = (anterior.latitude - latitude) * metrosPorGrau;
  final x2 = (atual.longitude - longitude) * longitudeEmMetros;
  final y2 = (atual.latitude - latitude) * metrosPorGrau;
  final dx = x2 - x1;
  final dy = y2 - y1;
  final comprimentoQuadrado = dx * dx + dy * dy;
  if (comprimentoQuadrado == 0) return false;
  final fracao = -(x1 * dx + y1 * dy) / comprimentoQuadrado;
  // O ponto mais próximo deve ter ficado para trás, dentro do segmento.
  if (fracao <= 0 || fracao >= 1) return false;
  final x = x1 + fracao * dx;
  final y = y1 + fracao * dy;
  return x * x + y * y <= 30 * 30;
}
