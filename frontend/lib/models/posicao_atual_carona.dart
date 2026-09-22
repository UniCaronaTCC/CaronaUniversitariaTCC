import '../utils/conversores_json.dart';

class PosicaoAtualCarona {
  final double latitude;
  final double longitude;
  final double? direcao;
  final double precisao;
  final DateTime atualizadoEm;

  const PosicaoAtualCarona({
    required this.latitude,
    required this.longitude,
    this.direcao,
    required this.precisao,
    required this.atualizadoEm,
  });

  factory PosicaoAtualCarona.fromJson(Map<String, dynamic> json) {
    final latitude = converterJsonParaDouble(json['latitude']);
    final longitude = converterJsonParaDouble(json['longitude']);
    final precisao = converterJsonParaDouble(json['precisao']);
    final atualizadoEm = DateTime.tryParse(
      json['atualizadoEm']?.toString() ?? '',
    );

    if (!_coordenadaValida(latitude, longitude) ||
        !precisao.isFinite ||
        precisao < 0 ||
        atualizadoEm == null) {
      throw const FormatException('Posição inválida');
    }

    final direcao = converterJsonParaDoubleOpcional(json['direcao']);
    return PosicaoAtualCarona(
      latitude: latitude,
      longitude: longitude,
      direcao: direcao != null && direcao.isFinite && direcao >= 0
          ? direcao % 360
          : null,
      precisao: precisao,
      atualizadoEm: atualizadoEm,
    );
  }

  static bool _coordenadaValida(double latitude, double longitude) =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;
}
