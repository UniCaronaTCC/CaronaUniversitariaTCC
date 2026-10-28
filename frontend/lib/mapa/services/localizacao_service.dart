import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class FiltroLocalizacaoGps {
  final double precisaoMaxima;
  final double distanciaSalto;
  final double toleranciaConfirmacao;
  // Limite de plausibilidade em metros por segundo, não limite da via.
  final double velocidadeMaxima;

  LatLng? _ultimaAceita;
  LatLng? _saltoPendente;
  DateTime? _instanteUltimaAceita;
  DateTime? _instanteSaltoPendente;
  DateTime? _instanteUltimaRecebida;

  FiltroLocalizacaoGps({
    this.precisaoMaxima = 40,
    this.distanciaSalto = 60,
    this.toleranciaConfirmacao = 45,
    this.velocidadeMaxima = 55,
  });

  bool aceitar({
    required double latitude,
    required double longitude,
    required double precisao,
    required DateTime instante,
  }) {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        !precisao.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180 ||
        precisao < 0 ||
        precisao > precisaoMaxima) {
      return false;
    }

    final data = instante;
    final ultimaData = _instanteUltimaRecebida;
    if (ultimaData != null && !data.isAfter(ultimaData)) return false;
    _instanteUltimaRecebida = data;
    final atual = LatLng(latitude, longitude);
    final ultima = _ultimaAceita;
    if (ultima == null ||
        _movimentoPlausivel(
          ultima,
          _instanteUltimaAceita!,
          atual,
          data,
          distanciaSalto,
        )) {
      _confirmar(atual, data);
      return true;
    }

    final pendente = _saltoPendente;
    if (pendente != null &&
        _movimentoPlausivel(
          pendente,
          _instanteSaltoPendente!,
          atual,
          data,
          toleranciaConfirmacao,
        )) {
      _confirmar(atual, data);
      return true;
    }

    _saltoPendente = atual;
    _instanteSaltoPendente = data;
    return false;
  }

  double _distancia(LatLng inicio, LatLng fim) =>
      const Distance().as(LengthUnit.Meter, inicio, fim);

  bool _movimentoPlausivel(
    LatLng anterior,
    DateTime instanteAnterior,
    LatLng atual,
    DateTime instanteAtual,
    double toleranciaMinima,
  ) {
    // Um carro pode percorrer mais de 60 m entre leituras na rodovia.
    // A tolerância acompanha o tempo, mantendo proteção contra saltos isolados.
    final segundos =
        instanteAtual.difference(instanteAnterior).inMicroseconds /
        Duration.microsecondsPerSecond;
    final limite = math.max(
      toleranciaMinima,
      velocidadeMaxima * segundos.clamp(0, 20),
    );
    return _distancia(anterior, atual) <= limite;
  }

  void _confirmar(LatLng posicao, DateTime instante) {
    _ultimaAceita = posicao;
    _instanteUltimaAceita = instante;
    _saltoPendente = null;
    _instanteSaltoPendente = null;
  }
}

/// aqui é onde pega/solicita a localizacao do usuario.
class LocalizacaoService {
  Future<void> _verificarDisponibilidade() async {
    final servicoHabilitado = await Geolocator.isLocationServiceEnabled();
    if (!servicoHabilitado) {
      throw Exception('O serviço de localização está desativado.');
    }

    var permissao = await Geolocator.checkPermission();
    if (permissao == LocationPermission.denied) {
      permissao = await Geolocator.requestPermission();
    }
    if (permissao == LocationPermission.denied) {
      throw Exception('Permissão de localização negada.');
    }
    if (permissao == LocationPermission.deniedForever) {
      throw Exception('Permissão de localização negada permanentemente.');
    }
  }

  /// Obtém a localização atual do usuário.
  Future<Position> obterLocalizacaoAtual() async {
    await _verificarDisponibilidade();

    // Obtém e retorna a posição atual do usuário.
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  /// Acompanha o aparelho em primeiro plano e evita atualizações excessivas.
  Future<Stream<Position>> acompanharLocalizacao() async {
    await _verificarDisponibilidade();
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      ),
    );
  }
}
