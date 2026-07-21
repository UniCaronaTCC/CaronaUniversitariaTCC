import 'package:geolocator/geolocator.dart';

/// aqui é onde pega/solicita a localizacao do usuario.
class LocalizacaoService {
  /// Obtém a localização atual do usuário.
  Future<Position> obterLocalizacaoAtual() async {
    // Verifica se a localização do aparelho está ligada.
    bool servicoHabilitado = await Geolocator.isLocationServiceEnabled();

    if (!servicoHabilitado) {
      throw Exception('O serviço de localização está desativado.');
    }

    // Verifica a permissão atual do aplicativo.
    LocationPermission permissao = await Geolocator.checkPermission();

    // Caso ainda não tenha sido permitida, solicita ao usuário.
    if (permissao == LocationPermission.denied) {
      permissao = await Geolocator.requestPermission();
    }

    // Caso o usuário negue dnv, interrompe a execução.
    if (permissao == LocationPermission.denied) {
      throw Exception('Permissão de localização negada.');
    }

    // Caso o usuário tenha negado permanentemente.
    if (permissao == LocationPermission.deniedForever) {
      throw Exception('Permissão de localização negada permanentemente.');
    }

    // Obtém e retorna a posição atual do usuário.
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }
}
