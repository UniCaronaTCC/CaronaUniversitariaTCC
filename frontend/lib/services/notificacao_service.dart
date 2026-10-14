import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/notificacao.dart';
import 'auth_service.dart';

class NotificacaoService {
  final http.Client? cliente;
  const NotificacaoService({this.cliente});

  Future<Map<String, dynamic>> contar() => _requisicao('nao-lidas');
  Future<Map<String, dynamic>> abrir() => _requisicao('abrir', abrir: true);
  Future<Map<String, dynamic>> listar({int? antesDe}) =>
      _requisicao('', antesDe: antesDe);

  Future<Map<String, dynamic>> _requisicao(
    String caminho, {
    bool abrir = false,
    int? antesDe,
  }) async {
    final client = cliente ?? http.Client();
    try {
      final url = Uri.parse(
        '${ApiConfig.baseUrl}/notificacoes${caminho.isEmpty ? '' : '/$caminho'}',
      ).replace(queryParameters: antesDe == null ? null : {'antesDe': '$antesDe'});
      final resposta = await AuthService.enviarComToken((token) {
        final headers = {'Authorization': 'Bearer $token'};
        return abrir
            ? client.post(url, headers: headers)
            : client.get(url, headers: headers);
      }).timeout(const Duration(seconds: 15));
      if (resposta == null || resposta.statusCode == 401) {
        return {
          'sucesso': false,
          'mensagem': 'Entre novamente para consultar as notificações',
        };
      }
      final json = jsonDecode(resposta.body);
      if (json is! Map ||
          resposta.statusCode < 200 ||
          resposta.statusCode >= 300 ||
          json['sucesso'] != true) {
        return {
          'sucesso': false,
          'mensagem':
              'Não foi possível consultar as notificações. Tente novamente',
        };
      }
      final dados = json['dados'];
      if (caminho == 'nao-lidas') {
        if (dados is! Map ||
            dados['total'] is! int ||
            (dados['total'] as int) < 0) {
          throw const FormatException('Contador invalido');
        }
        return {'sucesso': true, 'dados': dados['total']};
      }
      return {
        'sucesso': true,
        'dados': PaginaNotificacoes.fromJson(
          Map<String, dynamic>.from(dados as Map),
        ),
      };
    } catch (_) {
      return {
        'sucesso': false,
        'mensagem':
            'Não foi possível carregar as notificações. Confira a conexão e tente novamente',
      };
    } finally {
      if (cliente == null) client.close();
    }
  }
}
