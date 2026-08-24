import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class EmailVerificacaoService {
  static Future<Map<String, dynamic>> confirmarEmail(
      String email,
      String codigo,
      ) async {
    try {
      final url = Uri.parse(
        '${ApiConfig.baseUrl}/auth/confirmar-email',
      );

      final resposta = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'codigo': codigo,
        }),
      );

      final Map<String, dynamic> dados =
      resposta.body.isNotEmpty
          ? jsonDecode(resposta.body)
          : {};

      if (resposta.statusCode == 200 ||
          resposta.statusCode == 201) {
        return {
          'sucesso': true,
          'mensagem':
          dados['mensagem'] ??
              'E-mail confirmado com sucesso',
        };
      }

      return {
        'sucesso': false,
        'mensagem':
        dados['mensagem'] ??
            dados['message'] ??
            'Erro ao confirmar e-mail',
      };
    } catch (erro) {
      return {
        'sucesso': false,
        'mensagem':
        'Não foi possível conectar ao servidor',
      };
    }
  }

  static Future<Map<String, dynamic>> reenviarCodigo(
      String email,
      ) async {
    try {
      final url = Uri.parse(
        '${ApiConfig.baseUrl}/auth/reenviar-codigo',
      );

      final resposta = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
        }),
      );

      final Map<String, dynamic> dados =
      resposta.body.isNotEmpty
          ? jsonDecode(resposta.body)
          : {};

      if (resposta.statusCode == 200 ||
          resposta.statusCode == 201) {
        return {
          'sucesso': true,
          'mensagem':
          dados['mensagem'] ??
              'Novo código enviado',
        };
      }

      return {
        'sucesso': false,
        'mensagem':
        dados['mensagem'] ??
            dados['message'] ??
            'Erro ao reenviar código',
      };
    } catch (erro) {
      return {
        'sucesso': false,
        'mensagem':
        'Não foi possível conectar ao servidor',
      };
    }
  }

  static Future<Map<String, dynamic>> solicitarRedefinicaoSenha(
    String email,
  ) async {
    try {
      final resposta = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/esqueci-senha'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      final Map<String, dynamic> dados = resposta.body.isNotEmpty
          ? jsonDecode(resposta.body)
          : {};

      if (resposta.statusCode == 200 || resposta.statusCode == 201) {
        return {
          'sucesso': true,
          'mensagem': dados['mensagem'] ?? 'Código enviado para o seu e-mail',
        };
      }

      return {
        'sucesso': false,
        'mensagem':
            dados['mensagem'] ??
            dados['message'] ??
            'Não foi possível solicitar a redefinição',
      };
    } catch (erro) {
      return {
        'sucesso': false,
        'mensagem': 'Não foi possível conectar ao servidor',
      };
    }
  }

  static Future<Map<String, dynamic>> redefinirSenha(
    String email,
    String codigo,
    String novaSenha,
  ) async {
    try {
      final resposta = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/redefinir-senha'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'codigo': codigo,
          'novaSenha': novaSenha,
        }),
      );

      final Map<String, dynamic> dados = resposta.body.isNotEmpty
          ? jsonDecode(resposta.body)
          : {};

      if (resposta.statusCode == 200 || resposta.statusCode == 201) {
        return {
          'sucesso': true,
          'mensagem': dados['mensagem'] ?? 'Senha redefinida com sucesso',
        };
      }

      return {
        'sucesso': false,
        'mensagem':
            dados['mensagem'] ??
            dados['message'] ??
            'Não foi possível redefinir a senha',
      };
    } catch (erro) {
      return {
        'sucesso': false,
        'mensagem': 'Não foi possível conectar ao servidor',
      };
    }
  }
}
