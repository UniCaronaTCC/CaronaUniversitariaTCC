import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';

class CaronaService {
  // Busca todas as caronas ativas.
  static Future<Map<String, dynamic>> listarCaronas() async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/caronas');
      final resposta = await http.get(url);

      final dados = _decodificarResposta(resposta);

      if (resposta.statusCode == 200) {
        return {'sucesso': true, 'dados': dados};
      }

      return {
        'sucesso': false,
        'mensagem': _obterMensagem(dados, 'Erro ao buscar caronas'),
      };
    } catch (erro) {
      return {
        'sucesso': false,
        'mensagem': 'Não foi possível conectar ao servidor',
      };
    }
  }

  // Envia uma nova oferta com endereço e coordenadas.
  static Future<Map<String, dynamic>> criarCarona({
    required String origem,
    String? origemCidade,
    required double origemLatitude,
    required double origemLongitude,

    required String destino,
    String? destinoCidade,
    required double destinoLatitude,
    required double destinoLongitude,

    required String dataInicio,
    String? dataFim,
    required String horario,
    required int vagas,
    required double valor,
    required bool recorrente,
    List<String>? diasSemana,
    String? observacoes,
  }) async {
    try {
      final token = AuthService.tokenUsuarioLogado;

      if (token == null) {
        return {'sucesso': false, 'mensagem': 'Usuário não está logado'};
      }

      final url = Uri.parse('${ApiConfig.baseUrl}/caronas');

      final resposta = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'origem': origem,
          'origemCidade': origemCidade,
          'origemLatitude': origemLatitude,
          'origemLongitude': origemLongitude,

          'destino': destino,
          'destinoCidade': destinoCidade,
          'destinoLatitude': destinoLatitude,
          'destinoLongitude': destinoLongitude,

          'dataInicio': dataInicio,
          'dataFim': dataFim,
          'horario': horario,
          'vagas': vagas,
          'valor': valor,
          'recorrente': recorrente,
          'diasSemana': diasSemana,
          'observacoes': observacoes,
        }),
      );

      final dados = _decodificarResposta(resposta);

      if (resposta.statusCode == 200 || resposta.statusCode == 201) {
        return {'sucesso': true, 'dados': dados};
      }

      // Limpa a sessao quando o token for invalido ou expirado.
      if (resposta.statusCode == 401) {
        AuthService.sair();

        return {
          'sucesso': false,
          'mensagem': 'Sua sessão expirou. Entre novamente.',
        };
      }

      return {
        'sucesso': false,
        'mensagem': _obterMensagem(dados, 'Erro ao criar carona'),
      };
    } catch (erro) {
      return {
        'sucesso': false,
        'mensagem': 'Não foi possível conectar ao servidor',
      };
    }
  }

  // Converte com seguranca a resposta recebida.
  static Map<String, dynamic> _decodificarResposta(http.Response resposta) {
    if (resposta.body.isEmpty) {
      return {};
    }

    try {
      final resultado = jsonDecode(resposta.body);

      if (resultado is Map<String, dynamic>) {
        return resultado;
      }

      return {};
    } catch (erro) {
      return {};
    }
  }

  // Aceita tanto "mensagem" quanto "message".
  static String _obterMensagem(
    Map<String, dynamic> dados,
    String mensagemPadrao,
  ) {
    return dados['mensagem'] ?? dados['message'] ?? mensagemPadrao;
  }
}
