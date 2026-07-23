import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class AuthService {
  // Por enquanto, a sessão dura somente enquanto o app estiver aberto.
  static String? tokenUsuarioLogado;
  static Map<String, dynamic>? usuarioLogado;

  static bool get estaLogado => tokenUsuarioLogado != null;

  static void sair() {
    tokenUsuarioLogado = null;
    usuarioLogado = null;
  }

  static Future<Map<String, dynamic>> fazerLogin(
    String email,
    String senha,
  ) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/auth/login');
      final resposta = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'senha': senha}),
      );

      final Map<String, dynamic> dados = resposta.body.isNotEmpty
          ? jsonDecode(resposta.body)
          : {};

      if (resposta.statusCode == 200 || resposta.statusCode == 201) {
        tokenUsuarioLogado = dados['token'];

        if (dados['usuario'] is Map<String, dynamic>) {
          usuarioLogado = dados['usuario'];
        }

        return {'sucesso': true, 'dados': dados};
      }

      sair();

      return {
        'sucesso': false,
        'mensagem':
            dados['mensagem'] ?? dados['message'] ?? 'Erro ao fazer login',
      };
    } catch (erro) {
      sair();

      return {
        'sucesso': false,
        'mensagem': 'Não foi possível conectar ao servidor',
      };
    }
  }

  static Future<Map<String, dynamic>> fazerCadastro(
    String nome,
    String email,
    String senha,
  ) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/auth/cadastro');
      final resposta = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'nome': nome, 'email': email, 'senha': senha}),
      );

      final Map<String, dynamic> dados = resposta.body.isNotEmpty
          ? jsonDecode(resposta.body)
          : {};

      if (resposta.statusCode == 200 || resposta.statusCode == 201) {
        return {'sucesso': true, 'dados': dados};
      }

      return {
        'sucesso': false,
        'mensagem':
            dados['mensagem'] ?? dados['message'] ?? 'Erro ao cadastrar',
      };
    } catch (erro) {
      return {
        'sucesso': false,
        'mensagem': 'Não foi possível conectar ao servidor',
      };
    }
  }
}
