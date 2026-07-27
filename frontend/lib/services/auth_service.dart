import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'sessao_service.dart';

class AuthService {
  static String? tokenUsuarioLogado;
  static Map<String, dynamic>? usuarioLogado;

  static bool get estaLogado => tokenUsuarioLogado != null;

  static Future<void> carregarSessao() async {
    try {
      final sessao = await SessaoService.carregar();

      if (sessao == null) {
        tokenUsuarioLogado = null;
        usuarioLogado = null;
        return;
      }

      tokenUsuarioLogado = sessao['token']?.toString();
      usuarioLogado = sessao['usuario'] as Map<String, dynamic>?;
    } catch (erro) {
      tokenUsuarioLogado = null;
      usuarioLogado = null;
      await SessaoService.limpar();
    }
  }

  static Future<void> sair() async {
    tokenUsuarioLogado = null;
    usuarioLogado = null;
    await SessaoService.limpar();
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
        tokenUsuarioLogado = dados['token']?.toString();

        if (dados['usuario'] is Map<String, dynamic>) {
          usuarioLogado = dados['usuario'];
        }

        if (tokenUsuarioLogado == null || usuarioLogado == null) {
          await sair();

          return {'sucesso': false, 'mensagem': 'Resposta de login inválida'};
        }

        await SessaoService.salvar(tokenUsuarioLogado!, usuarioLogado!);

        return {'sucesso': true, 'dados': dados};
      }

      await sair();

      return {
        'sucesso': false,
        'mensagem':
            dados['mensagem'] ?? dados['message'] ?? 'Erro ao fazer login',
      };
    } catch (erro) {
      await sair();

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
