import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';
import 'cliente_http_com_prazo.dart';
import 'memoria_resumo_perfil.dart';

class AvaliacaoService {
  static EscopoResumoPerfil? get _escopoAtual {
    final id = int.tryParse(AuthService.usuarioLogado?['id']?.toString() ?? '');
    return AuthService.estaLogado && id != null && id > 0
        ? (id, AuthService.versaoSessao)
        : null;
  }

  static ResumoAvaliacoesPerfil? lerResumoPerfil() {
    final escopo = _escopoAtual;
    return escopo == null
        ? null
        : MemoriaResumoPerfil.compartilhada.ler(escopo);
  }

  static Future<Map<String, dynamic>> atualizarResumoPerfil({
    bool invalidar = false,
  }) {
    final escopo = _escopoAtual;
    if (escopo == null) {
      return Future.value({
        'sucesso': false,
        'mensagem': 'Usuário não está logado',
      });
    }
    final memoria = MemoriaResumoPerfil.compartilhada;
    if (invalidar) memoria.invalidar(escopo);
    return memoria.atualizar(escopo, () => listarRecebidas(escopo.$1));
  }

  static Future<Map<String, dynamic>> enviar({
    required int idSolicitacao,
    required int nota,
    String? comentario,
  }) async {
    try {
      final resposta = await AuthService.enviarComToken(
        (token) => http.post(
          Uri.parse('${ApiConfig.baseUrl}/avaliacoes'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'idSolicitacao': idSolicitacao,
            'nota': nota,
            'comentario': comentario,
          }),
        ),
      );

      if (resposta == null) {
        return {'sucesso': false, 'mensagem': 'Usuário não está logado'};
      }

      final corpo = _decodificarResposta(resposta.body);

      if (resposta.statusCode == 200 || resposta.statusCode == 201) {
        return {
          'sucesso': true,
          'mensagem':
              corpo['mensagem']?.toString() ?? 'Avaliação enviada com sucesso',
        };
      }

      if (resposta.statusCode == 401) {
        await AuthService.sair();
      }

      return {
        'sucesso': false,
        'mensagem':
            corpo['mensagem'] ?? corpo['message'] ?? 'Erro ao enviar avaliação',
      };
    } catch (erro) {
      return {
        'sucesso': false,
        'mensagem': 'Não foi possível conectar ao servidor',
      };
    }
  }

  static Future<Map<String, dynamic>> listarRecebidas(
    int idUsuario, {
    int pagina = 1,
  }) async {
    final cliente = ClienteHttpComPrazo();
    try {
      final url = Uri.parse(
        '${ApiConfig.baseUrl}/usuarios/$idUsuario/avaliacoes?pagina=$pagina',
      );
      final resposta = await AuthService.enviarComToken(
        (token) =>
            cliente.get(url, headers: {'Authorization': 'Bearer $token'}),
      ).timeout(const Duration(seconds: 20));

      if (resposta == null) {
        return {'sucesso': false, 'mensagem': 'Usuário não está logado'};
      }

      final corpo = _decodificarResposta(resposta.body);

      if (resposta.statusCode == 200) {
        if (corpo['sucesso'] == false || corpo['dados'] is! Map) {
          throw const FormatException('Resposta de avaliacoes invalida');
        }
        return {
          'sucesso': true,
          'dados': Map<String, dynamic>.from(corpo['dados']),
        };
      }

      if (resposta.statusCode == 401) {
        await AuthService.sair();
      }

      return {
        'sucesso': false,
        'mensagem':
            corpo['mensagem'] ??
            corpo['message'] ??
            'Erro ao buscar avaliações',
      };
    } on TimeoutException {
      return {
        'sucesso': false,
        'mensagem': 'O servidor demorou para responder. Tente novamente',
      };
    } on FormatException {
      return {
        'sucesso': false,
        'mensagem':
            'O servidor retornou uma resposta inválida ao consultar avaliações. Tente novamente.',
      };
    } catch (erro) {
      return {
        'sucesso': false,
        'mensagem': 'Não foi possível conectar ao servidor',
      };
    } finally {
      cliente.close();
    }
  }

  static Map<String, dynamic> _decodificarResposta(String corpo) {
    if (corpo.isEmpty) {
      return {};
    }

    try {
      final resultado = jsonDecode(corpo);

      return resultado is Map<String, dynamic> ? resultado : {};
    } catch (erro) {
      return {};
    }
  }
}
