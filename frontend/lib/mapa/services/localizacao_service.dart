import 'package:geolocator/geolocator.dart';

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
