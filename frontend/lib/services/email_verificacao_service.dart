import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_auth_service.dart';

class EmailVerificacaoService {
  static Map<String, dynamic> get _erroConfiguracao => {
    'sucesso': false,
    'mensagem': 'Supabase não configurado no aplicativo',
  };

  static Future<Map<String, dynamic>> confirmarEmail(
    String email,
    String codigo,
  ) async {
    if (!SupabaseAuthService.configurado) return _erroConfiguracao;

    try {
      await SupabaseAuthService.confirmarEmail(email, codigo);
      return {'sucesso': true, 'mensagem': 'E-mail confirmado com sucesso'};
    } on AuthException catch (erro) {
      return {'sucesso': false, 'mensagem': erro.message};
    }
  }

  static Future<Map<String, dynamic>> reenviarCodigo(String email) async {
    if (!SupabaseAuthService.configurado) return _erroConfiguracao;

    try {
      await SupabaseAuthService.reenviarCodigo(email);
      return {'sucesso': true, 'mensagem': 'Novo código enviado'};
    } on AuthException catch (erro) {
      return {'sucesso': false, 'mensagem': erro.message};
    }
  }

  static Future<Map<String, dynamic>> solicitarRedefinicaoSenha(
    String email,
  ) async {
    if (!SupabaseAuthService.configurado) return _erroConfiguracao;

    try {
      await SupabaseAuthService.solicitarRedefinicao(email);
      return {'sucesso': true, 'mensagem': 'Código enviado para o seu e-mail'};
    } on AuthException catch (erro) {
      return {'sucesso': false, 'mensagem': erro.message};
    }
  }

  static Future<Map<String, dynamic>> redefinirSenha(
    String email,
    String codigo,
    String novaSenha,
  ) async {
    if (!SupabaseAuthService.configurado) return _erroConfiguracao;

    try {
      await SupabaseAuthService.redefinirSenha(email, codigo, novaSenha);
      return {'sucesso': true, 'mensagem': 'Senha redefinida com sucesso'};
    } on AuthException catch (erro) {
      return {'sucesso': false, 'mensagem': erro.message};
    }
  }
}
