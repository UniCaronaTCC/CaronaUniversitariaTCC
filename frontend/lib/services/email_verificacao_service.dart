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
}