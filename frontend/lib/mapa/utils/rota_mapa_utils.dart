import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../../models/carona.dart';
import '../../models/ponto_embarque.dart';

bool coordenadaValida(double? latitude, double? longitude) {
  return latitude != null &&
      longitude != null &&
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;
}

int chavePontoEmbarque(PontoEmbarque ponto) => ponto.id ?? -ponto.ordem;

List<PontoEmbarque> pontosOrdenados(Carona carona) {
  return [...carona.pontosEmbarque]..sort((a, b) => a.ordem.compareTo(b.ordem));
}

List<LatLng>? paradasDaCarona(Carona carona) {
  final pontos = pontosOrdenados(carona);
  if (!coordenadaValida(carona.origemLatitude, carona.origemLongitude) ||
      !coordenadaValida(carona.destinoLatitude, carona.destinoLongitude) ||
      pontos.any((p) => !coordenadaValida(p.latitude, p.longitude))) {
    return null;
  }
  return [
    LatLng(carona.origemLatitude!, carona.origemLongitude!),
    ...pontos.map((p) => LatLng(p.latitude, p.longitude)),
    LatLng(carona.destinoLatitude!, carona.destinoLongitude!),
  ];
}

List<LatLng>? paradasDaNavegacao(
  Carona carona,
  LatLng localizacaoMotorista,
  Set<int> embarquesConcluidos,
) {
  final pontos = pontosOrdenados(carona);
  if (!coordenadaValida(carona.destinoLatitude, carona.destinoLongitude) ||
      pontos.any((p) => !coordenadaValida(p.latitude, p.longitude))) {
    return null;
  }
  return removerPontosConsecutivosProximos([
    localizacaoMotorista,
    ...pontos
        .where(
          (ponto) => !embarquesConcluidos.contains(chavePontoEmbarque(ponto)),
        )
        .map((p) => LatLng(p.latitude, p.longitude)),
    LatLng(carona.destinoLatitude!, carona.destinoLongitude!),
  ]);
}

List<LatLng> removerPontosConsecutivosProximos(List<LatLng> pontos) {
  if (pontos.length < 2) return pontos;
  const distancia = Distance();
  final resultado = <LatLng>[pontos.first];
  for (final ponto in pontos.skip(1)) {
    if (distancia.as(LengthUnit.Meter, resultado.last, ponto) >= 20) {
      resultado.add(ponto);
    }
  }
  return resultado;
}

double direcaoInicial(List<LatLng> pontos) {
  if (pontos.length < 2) return 0;
  final inicio = pontos.first;
  final proximo = pontos.firstWhere(
    (ponto) => ponto != inicio,
    orElse: () => pontos.last,
  );
  final latitude1 = inicio.latitudeInRad;
  final latitude2 = proximo.latitudeInRad;
  final diferencaLongitude =
      (proximo.longitude - inicio.longitude) * math.pi / 180;
  final y = math.sin(diferencaLongitude) * math.cos(latitude2);
  final x =
      math.cos(latitude1) * math.sin(latitude2) -
      math.sin(latitude1) * math.cos(latitude2) * math.cos(diferencaLongitude);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

String duracaoFormatada(double segundos) {
  final minutos = (segundos / 60).ceil();
  if (minutos < 1) return 'Menos de 1 min';
  if (minutos < 60) return '$minutos min';
  final restante = minutos % 60;
  return '${minutos ~/ 60} h${restante == 0 ? '' : ' $restante min'}';
}
