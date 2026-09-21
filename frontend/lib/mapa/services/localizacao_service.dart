import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class FiltroLocalizacaoGps {
  final double precisaoMaxima;
  final double distanciaSalto;
  final double toleranciaConfirmacao;

  LatLng? _ultimaAceita;
  LatLng? _saltoPendente;

  FiltroLocalizacaoGps({
    this.precisaoMaxima = 40,
    this.distanciaSalto = 60,
    this.toleranciaConfirmacao = 45,
  });

  bool aceitar({
    required double latitude,
    required double longitude,
    required double precisao,
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

    final atual = LatLng(latitude, longitude);
    final ultima = _ultimaAceita;
    if (ultima == null || _distancia(ultima, atual) <= distanciaSalto) {
      _confirmar(atual);
      return true;
    }

    final pendente = _saltoPendente;
    if (pendente != null &&
        _distancia(pendente, atual) <= toleranciaConfirmacao) {
      _confirmar(atual);
      return true;
    }

    _saltoPendente = atual;
    return false;
  }

  double _distancia(LatLng inicio, LatLng fim) =>
      const Distance().as(LengthUnit.Meter, inicio, fim);

  void _confirmar(LatLng posicao) {
    _ultimaAceita = posicao;
    _saltoPendente = null;
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
        distanceFilter: 5,
      ),
    );
  }
}
