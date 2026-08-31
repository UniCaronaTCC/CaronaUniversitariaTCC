import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/api_config.dart';
import 'supabase_auth_service.dart';

class EmailVerificacaoService {
  static Future<Map<String, dynamic>> confirmarEmail(
    String email,
    String codigo,
  ) async {
    if (SupabaseAuthService.configurado) {
      try {
        await SupabaseAuthService.confirmarEmail(email, codigo);
        return {'sucesso': true, 'mensagem': 'E-mail confirmado com sucesso'};
      } on AuthException catch (erro) {
        return {'sucesso': false, 'mensagem': erro.message};
      }
    }

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/auth/confirmar-email');

      final resposta = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'codigo': codigo}),
      );

      final Map<String, dynamic> dados = resposta.body.isNotEmpty
          ? jsonDecode(resposta.body)
          : {};

      if (resposta.statusCode == 200 || resposta.statusCode == 201) {
        return {
          'sucesso': true,
          'mensagem': dados['mensagem'] ?? 'E-mail confirmado com sucesso',
        };
      }

      return {
        'sucesso': false,
        'mensagem':
            dados['mensagem'] ?? dados['message'] ?? 'Erro ao confirmar e-mail',
      };
    } catch (erro) {
      return {
        'sucesso': false,
        'mensagem': 'Não foi possível conectar ao servidor',
      };
    }
  }

  static Future<Map<String, dynamic>> reenviarCodigo(String email) async {
    if (SupabaseAuthService.configurado) {
      try {
        await SupabaseAuthService.reenviarCodigo(email);
        return {'sucesso': true, 'mensagem': 'Novo código enviado'};
      } on AuthException catch (erro) {
        return {'sucesso': false, 'mensagem': erro.message};
      }
    }

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/auth/reenviar-codigo');

      final resposta = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      final Map<String, dynamic> dados = resposta.body.isNotEmpty
          ? jsonDecode(resposta.body)
          : {};

      if (resposta.statusCode == 200 || resposta.statusCode == 201) {
        return {
          'sucesso': true,
          'mensagem': dados['mensagem'] ?? 'Novo código enviado',
        };
      }

      return {
        'sucesso': false,
        'mensagem':
            dados['mensagem'] ?? dados['message'] ?? 'Erro ao reenviar código',
      };
    } catch (erro) {
      return {
        'sucesso': false,
        'mensagem': 'Não foi possível conectar ao servidor',
      };
    }
  }

  static Future<Map<String, dynamic>> solicitarRedefinicaoSenha(
    String email,
  ) async {
    if (SupabaseAuthService.configurado) {
      try {
        await SupabaseAuthService.solicitarRedefinicao(email);
        return {
          'sucesso': true,
          'mensagem': 'Código enviado para o seu e-mail',
        };
      } on AuthException catch (erro) {
        return {'sucesso': false, 'mensagem': erro.message};
      }
    }

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
    if (SupabaseAuthService.configurado) {
      try {
        await SupabaseAuthService.redefinirSenha(email, codigo, novaSenha);
        return {'sucesso': true, 'mensagem': 'Senha redefinida com sucesso'};
      } on AuthException catch (erro) {
        return {'sucesso': false, 'mensagem': erro.message};
      }
    }

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
