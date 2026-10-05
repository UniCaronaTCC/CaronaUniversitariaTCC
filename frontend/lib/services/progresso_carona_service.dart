import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/ponto_embarque.dart';
import 'auth_service.dart';

class ErroProgresso implements Exception {
  final String mensagem;
  final bool temporario;
  const ErroProgresso(this.mensagem, {this.temporario = true});
  @override
  String toString() => mensagem;
}

class ProgressoCaronaService {
  Future<List<PontoEmbarque>> consultar(int idCarona) => _requisicao(idCarona);
  Future<List<PontoEmbarque>> marcar(int idCarona, int idPonto) =>
      _requisicao(idCarona, idPonto);

  Future<List<PontoEmbarque>> _requisicao(int idCarona, [int? idPonto]) async {
    final url = Uri.parse(
      '${ApiConfig.baseUrl}/caronas/$idCarona/progresso'
      '${idPonto == null ? '' : '/$idPonto'}',
    );
    final resposta = await AuthService.enviarComToken((token) {
      final headers = {'Authorization': 'Bearer $token'};
      return (idPonto == null
              ? http.get(url, headers: headers)
              : http.put(url, headers: headers))
          .timeout(const Duration(seconds: 4));
    });
    if (resposta == null) {
      throw const ErroProgresso(
        'Entre novamente para acompanhar o percurso.',
        temporario: false,
      );
    }
    if (resposta.statusCode != 200) {
      throw ErroProgresso(
        'Não foi possível atualizar os pontos do percurso.',
        temporario: resposta.statusCode >= 500 || resposta.statusCode == 429,
      );
    }
    final dados = jsonDecode(resposta.body)['dados'] as List;
    return dados
        .map((p) => PontoEmbarque.fromJson(Map<String, dynamic>.from(p)))
        .toList();
  }
}
