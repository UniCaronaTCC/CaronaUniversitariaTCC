import 'dart:convert';

import '../config/api_config.dart';
import '../mapa/services/endereco_service.dart';
import '../mapa/services/localizacao_service.dart';
import '../models/campus_destino.dart';
import 'cliente_http_com_prazo.dart';

class CampusDestinoService {
  const CampusDestinoService();

  Future<CidadeCampus?> identificarCidade() async {
    try {
      final posicao = await LocalizacaoService()
          .obterLocalizacaoAtual()
          .timeout(const Duration(seconds: 8));
      final local = await EnderecoService()
          .buscarLocalizacaoPorCoordenadas(posicao.latitude, posicao.longitude)
          .timeout(const Duration(seconds: 4));
      return CidadeCampus.deLocalizacao(local);
    } catch (_) {
      return null;
    }
  }

  Future<List<CampusDestino>> listar(
    CidadeCampus cidade, {
    Duration prazo = const Duration(seconds: 20),
  }) async {
    final cliente = ClienteHttpComPrazo(prazo: prazo);
    try {
      final url = Uri.parse(
        '${ApiConfig.baseUrl}/instituicoes/destinos',
      ).replace(queryParameters: {'cidade': cidade.cidade, 'uf': cidade.uf});
      final resposta = await cliente.get(url);
      if (resposta.statusCode != 200) {
        throw const FormatException('Falha ao consultar campi');
      }
      final json = jsonDecode(utf8.decode(resposta.bodyBytes));
      if (json is! Map || json['sucesso'] != true || json['dados'] is! List) {
        throw const FormatException('Resposta de campi inválida');
      }
      final porId = <int, CampusDestino>{};
      for (final dado in json['dados'] as List) {
        if (dado is! Map<String, dynamic>) {
          throw const FormatException('Campus inválido');
        }
        final campus = CampusDestino.fromJson(dado);
        if (!cidade.mesmaCidade(campus.cidade)) {
          throw const FormatException('Campus de outra cidade');
        }
        porId.putIfAbsent(campus.idCampus, () => campus);
      }
      return porId.values.toList();
    } finally {
      cliente.close();
    }
  }
}
