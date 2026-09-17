import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../config/api_config.dart';

class RotaResultado {
  final List<LatLng> pontos;
  final double distanciaMetros;
  final double duracaoSegundos;

  RotaResultado({
    required this.pontos,
    required this.distanciaMetros,
    required this.duracaoSegundos,
  });
}

class RotaService {
  Future<RotaResultado> calcularRota(List<LatLng> pontos) async {
    final resposta = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/rotas/calcular'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'coordenadas': pontos
            .map((ponto) => [ponto.longitude, ponto.latitude])
            .toList(),
      }),
    );

    if (resposta.statusCode != 201 && resposta.statusCode != 200) {
      throw Exception('Não foi possível calcular a rota');
    }

    final dados = jsonDecode(resposta.body);

    return RotaResultado(
      pontos: (dados['pontos'] as List)
          .map(
            (ponto) => LatLng(
          (ponto[0] as num).toDouble(),
          (ponto[1] as num).toDouble(),
        ),
      )
          .toList(),
      distanciaMetros: (dados['distanciaMetros'] as num).toDouble(),
      duracaoSegundos: (dados['duracaoSegundos'] as num).toDouble(),
    );
  }
}
