import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/carona.dart';
import '../models/ponto_embarque.dart';
import 'auth_service.dart';

class CaronaService {
  // Busca e converte as caronas ativas.
  static Future<Map<String, dynamic>> listarCaronas() {
    return _listarCaronas('caronas');
  }

  // Busca as ofertas publicadas pelo usuario logado.
  static Future<Map<String, dynamic>> listarMinhasCaronas() {
    return _listarCaronas('caronas/minhas');
  }

  static Future<Map<String, dynamic>> _listarCaronas(String rota) async {
    try {
      final token = AuthService.tokenUsuarioLogado;

      if (token == null) {
        return {'sucesso': false, 'mensagem': 'Usuário não está logado'};
      }

      final url = Uri.parse('${ApiConfig.baseUrl}/$rota');

      final resposta = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      final corpo = _decodificarResposta(resposta);

      if (resposta.statusCode == 200) {
        final caronas = <Carona>[];
        final dadosRecebidos = corpo['dados'];

        if (dadosRecebidos is List) {
          for (final item in dadosRecebidos) {
            if (item is! Map) {
              continue;
            }

            try {
              caronas.add(Carona.fromJson(Map<String, dynamic>.from(item)));
            } catch (erro) {
              // Ignora somente registros invalidos.
            }
          }
        }

        return {'sucesso': true, 'dados': caronas};
      }

      if (resposta.statusCode == 401) {
        AuthService.sair();

        return {
          'sucesso': false,
          'mensagem': 'Sua sessão expirou. Entre novamente.',
        };
      }

      return {
        'sucesso': false,
        'mensagem': _obterMensagem(corpo, 'Erro ao buscar caronas'),
      };
    } catch (erro) {
      return {
        'sucesso': false,
        'mensagem': 'Não foi possível conectar ao servidor',
      };
    }
  }

  // Cria ou atualiza uma oferta com endereço e coordenadas.
  static Future<Map<String, dynamic>> salvarCarona({
    int? idCarona,

    required String origem,
    String? origemCidade,
    required double origemLatitude,
    required double origemLongitude,

    required String destino,
    String? destinoCidade,
    required double destinoLatitude,
    required double destinoLongitude,

    List<PontoEmbarque> pontosEmbarque = const [],

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

      final url = Uri.parse(
        '${ApiConfig.baseUrl}/caronas${idCarona == null ? '' : '/$idCarona'}',
      );

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final corpoRequisicao = jsonEncode({
        'origem': origem,
        'origemCidade': origemCidade,
        'origemLatitude': origemLatitude,
        'origemLongitude': origemLongitude,

        'destino': destino,
        'destinoCidade': destinoCidade,
        'destinoLatitude': destinoLatitude,
        'destinoLongitude': destinoLongitude,

        // Envia os pontos escolhidos pelo motorista.
        'pontosEmbarque': pontosEmbarque
            .map((ponto) => ponto.toJson())
            .toList(),

        'dataInicio': dataInicio,
        'dataFim': dataFim,
        'horario': horario,
        'vagas': vagas,
        'valor': valor,
        'recorrente': recorrente,
        'diasSemana': diasSemana,
        'observacoes': observacoes,
      });

      final resposta = idCarona == null
          ? await http.post(url, headers: headers, body: corpoRequisicao)
          : await http.patch(url, headers: headers, body: corpoRequisicao);

      final corpo = _decodificarResposta(resposta);

      if (resposta.statusCode == 200 || resposta.statusCode == 201) {
        return {'sucesso': true, 'dados': corpo};
      }

      if (resposta.statusCode == 401) {
        AuthService.sair();

        return {
          'sucesso': false,
          'mensagem': 'Sua sessão expirou. Entre novamente.',
        };
      }

      return {
        'sucesso': false,
        'mensagem': _obterMensagem(corpo, 'Erro ao salvar carona'),
      };
    } catch (erro) {
      return {
        'sucesso': false,
        'mensagem': 'Não foi possível conectar ao servidor',
      };
    }
  }

  static Future<Map<String, dynamic>> excluirCarona(int idCarona) async {
    try {
      final token = AuthService.tokenUsuarioLogado;

      if (token == null) {
        return {'sucesso': false, 'mensagem': 'Usuário não está logado'};
      }

      final resposta = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/caronas/$idCarona'),
        headers: {'Authorization': 'Bearer $token'},
      );

      final corpo = _decodificarResposta(resposta);

      if (resposta.statusCode == 200) {
        return {
          'sucesso': true,
          'mensagem': corpo['mensagem']?.toString() ?? 'Carona excluída',
        };
      }

      if (resposta.statusCode == 401) {
        AuthService.sair();
      }

      return {
        'sucesso': false,
        'mensagem': _obterMensagem(corpo, 'Erro ao excluir carona'),
      };
    } catch (erro) {
      return {
        'sucesso': false,
        'mensagem': 'Não foi possível conectar ao servidor',
      };
    }
  }

  static Future<Map<String, dynamic>> iniciarCorrida(int idCarona) {
    return _alterarStatusCorrida(idCarona, 'iniciar');
  }

  static Future<Map<String, dynamic>> finalizarCorrida(int idCarona) {
    return _alterarStatusCorrida(idCarona, 'finalizar');
  }

  static Future<bool> atualizarPosicaoAtual({
    required int idCarona,
    required double latitude,
    required double longitude,
    required double precisao,
    double? direcao,
  }) async {
    try {
      final token = AuthService.tokenUsuarioLogado;
      if (token == null) return false;

      final resposta = await http
          .put(
            Uri.parse('${ApiConfig.baseUrl}/caronas/$idCarona/posicao'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'latitude': latitude,
              'longitude': longitude,
              'direcao': direcao,
              'precisao': precisao,
            }),
          )
          .timeout(const Duration(seconds: 4));

      if (resposta.statusCode == 401) {
        await AuthService.sair();
      }

      return resposta.statusCode == 200 || resposta.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> _alterarStatusCorrida(
    int idCarona,
    String acao,
  ) async {
    try {
      final token = AuthService.tokenUsuarioLogado;
      if (token == null) {
        return {'sucesso': false, 'mensagem': 'Usuário não está logado'};
      }

      final resposta = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/caronas/$idCarona/$acao'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final corpo = _decodificarResposta(resposta);

      if (resposta.statusCode == 200 || resposta.statusCode == 201) {
        final dados = corpo['dados'];
        if (dados is Map) {
          return {
            'sucesso': true,
            'mensagem': corpo['mensagem']?.toString(),
            'dados': Carona.fromJson(Map<String, dynamic>.from(dados)),
          };
        }
      }

      if (resposta.statusCode == 401) {
        await AuthService.sair();
        return {
          'sucesso': false,
          'mensagem': 'Sua sessão expirou. Entre novamente.',
        };
      }

      return {
        'sucesso': false,
        'mensagem': _obterMensagem(
          corpo,
          acao == 'iniciar'
              ? 'Não foi possível iniciar a corrida'
              : 'Não foi possível finalizar a corrida',
        ),
      };
    } catch (_) {
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

  static String _obterMensagem(
    Map<String, dynamic> dados,
    String mensagemPadrao,
  ) {
    final mensagem = dados['mensagem'] ?? dados['message'];

    return mensagem?.toString() ?? mensagemPadrao;
  }
}
