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
  final http.Client Function() _criarCliente;

  RotaService({http.Client Function()? criarCliente})
    : _criarCliente = criarCliente ?? http.Client.new;

  Future<RotaResultado> calcularRota(List<LatLng> pontos) async {
    if (pontos.isEmpty ||
        pontos.any(
          (p) =>
              !p.latitude.isFinite ||
              !p.longitude.isFinite ||
              p.latitude.abs() > 90 ||
              p.longitude.abs() > 180,
        )) {
      throw const FormatException('Coordenadas inválidas');
    }
    // Todos os pontos próximos foram agrupados: não há trecho a consultar.
    if (pontos.length == 1) {
      return RotaResultado(
        pontos: [pontos.first, pontos.first],
        distanciaMetros: 0,
        duracaoSegundos: 0,
      );
    }
    final cliente = _criarCliente();
    try {
      final resposta = await cliente
          .post(
            Uri.parse('${ApiConfig.baseUrl}/rotas/calcular'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'coordenadas': pontos
                  .map((ponto) => [ponto.longitude, ponto.latitude])
                  .toList(),
            }),
          )
          .timeout(const Duration(seconds: 40));

      if (resposta.statusCode != 201 && resposta.statusCode != 200) {
        throw Exception('Não foi possível calcular a rota');
      }

      final dados = jsonDecode(resposta.body);

      final rota = RotaResultado(
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
      if (rota.pontos.length < 2 ||
          rota.pontos.any(
            (p) =>
                !p.latitude.isFinite ||
                !p.longitude.isFinite ||
                p.latitude.abs() > 90 ||
                p.longitude.abs() > 180,
          ) ||
          !rota.distanciaMetros.isFinite ||
          rota.distanciaMetros < 0 ||
          !rota.duracaoSegundos.isFinite ||
          rota.duracaoSegundos < 0) {
        throw const FormatException('Rota inválida');
      }
      return rota;
    } finally {
      cliente.close();
    }
  }
}
