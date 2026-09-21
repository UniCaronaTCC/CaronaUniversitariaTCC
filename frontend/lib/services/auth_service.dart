import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/api_config.dart';
import 'sessao_service.dart';
import 'supabase_auth_service.dart';

class AuthService {
  static String? _tokenUsuarioLogado;
  static Map<String, dynamic>? usuarioLogado;

  static String? get tokenUsuarioLogado =>
      SupabaseAuthService.tokenAtual ?? _tokenUsuarioLogado;

  static set tokenUsuarioLogado(String? token) {
    _tokenUsuarioLogado = token;
  }

  static bool get estaLogado => tokenUsuarioLogado != null;

  static Future<void> carregarSessao() async {
    try {
      final sessao = await SessaoService.carregar();
      final tokenSupabase = SupabaseAuthService.tokenAtual;

      if (tokenSupabase == null) {
        tokenUsuarioLogado = null;
        usuarioLogado = null;
        await SessaoService.limpar();
        return;
      }

      tokenUsuarioLogado = tokenSupabase;
      usuarioLogado = sessao?['usuario'] as Map<String, dynamic>?;

      await buscarPerfil();
    } catch (erro) {
      tokenUsuarioLogado = null;
      usuarioLogado = null;
      await SessaoService.limpar();
    }
  }

  static Future<void> sair() async {
    try {
      await SupabaseAuthService.sair();
    } finally {
      tokenUsuarioLogado = null;
      usuarioLogado = null;
      await SessaoService.limpar();
    }
  }

  static Future<Map<String, dynamic>> fazerLogin(
    String email,
    String senha,
  ) async {
    if (!SupabaseAuthService.configurado) {
      return {
        'sucesso': false,
        'mensagem': 'Supabase não configurado no aplicativo',
      };
    }

    try {
      final resposta = await SupabaseAuthService.entrar(email, senha);
      tokenUsuarioLogado = resposta.session?.accessToken;

      if (tokenUsuarioLogado == null) {
        return {
          'sucesso': false,
          'mensagem': 'Confirme seu e-mail antes de entrar',
        };
      }

      final perfil = await buscarPerfil();

      if (perfil['sucesso'] != true) {
        return perfil;
      }

      return {
        'sucesso': true,
        'dados': {
          'mensagem': 'Login realizado com sucesso',
          'usuario': perfil['dados'],
        },
      };
    } on AuthException catch (erro) {
      return {
        'sucesso': false,
        'mensagem': _mensagemErroSupabase(erro),
      };
    } catch (erro) {
      return {'sucesso': false, 'mensagem': 'Não foi possível fazer login'};
    }
  }

  static Future<Map<String, dynamic>> fazerCadastro(
    String nome,
    String email,
    String senha,
  ) async {
    if (!SupabaseAuthService.configurado) {
      return {
        'sucesso': false,
        'mensagem': 'Supabase não configurado no aplicativo',
      };
    }

    try {
      await SupabaseAuthService.cadastrar(nome, email, senha);

      return {
        'sucesso': true,
        'dados': {
          'mensagem': 'Enviamos um código de confirmação para seu e-mail',
        },
      };
    } on AuthException catch (erro) {
      return {
        'sucesso': false,
        'mensagem': _mensagemErroSupabase(erro),
      };
    } catch (erro) {
      return {
        'sucesso': false,
        'mensagem': 'Não foi possível conectar ao serviço de cadastro',
      };
    }
  }

  static String _mensagemErroSupabase(AuthException erro) {
    switch (erro.code) {
      case 'invalid_credentials':
        return 'E-mail ou senha inválidos';
      case 'weak_password':
        return 'A senha não atende aos requisitos de segurança';
      case 'email_not_confirmed':
        return 'Confirme seu e-mail antes de entrar';
      case 'email_provider_disabled':
        return 'A autenticação por e-mail e senha está desativada';
      case 'over_request_rate_limit':
      case 'over_email_send_rate_limit':
        return 'Aguarde um pouco antes de tentar novamente';
      case 'email_exists':
      case 'user_already_exists':
        return 'Este e-mail já está cadastrado';
    }

    final texto = erro.message.toLowerCase();

    if (texto.contains('already registered') ||
        texto.contains('already been registered')) {
      return 'Este e-mail já está cadastrado';
    }

    if (texto.contains('rate limit')) {
      return 'Aguarde um pouco antes de tentar novamente';
    }

    if (texto.contains('invalid login credentials')) {
      return 'E-mail ou senha inválidos';
    }

    if (texto.contains('email not confirmed')) {
      return 'Confirme seu e-mail antes de entrar';
    }

    return erro.message;
  }

  static Future<Map<String, dynamic>> buscarPerfil() async {
    final token = tokenUsuarioLogado;

    if (token == null) {
      return {'sucesso': false, 'mensagem': 'Usuário não está logado'};
    }

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/usuarios/perfil');
      final resposta = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      final Map<String, dynamic> respostaJson = resposta.body.isNotEmpty
          ? jsonDecode(resposta.body)
          : {};

      if (resposta.statusCode == 200 &&
          respostaJson['dados'] is Map<String, dynamic>) {
        usuarioLogado = Map<String, dynamic>.from(respostaJson['dados']);
        await SessaoService.salvar(token, usuarioLogado!);

        return {'sucesso': true, 'dados': usuarioLogado};
      }

      if (resposta.statusCode == 401) {
        await sair();
      }

      return {
        'sucesso': false,
        'mensagem':
            respostaJson['mensagem'] ??
            respostaJson['message'] ??
            'Erro ao buscar perfil',
      };
    } catch (erro) {
      return {
        'sucesso': false,
        'mensagem': 'Não foi possível conectar ao servidor',
      };
    }
  }

  static Future<Map<String, dynamic>> atualizarPerfil(
    int idInstituicao,
    String campus,
  ) async {
    final token = tokenUsuarioLogado;

    if (token == null) {
      return {'sucesso': false, 'mensagem': 'Usuário não está logado'};
    }

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/usuarios/perfil');
      final resposta = await http.patch(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'idInstituicao': idInstituicao, 'campus': campus}),
      );

      final Map<String, dynamic> respostaJson = resposta.body.isNotEmpty
          ? jsonDecode(resposta.body)
          : {};

      if (resposta.statusCode == 200 &&
          respostaJson['dados'] is Map<String, dynamic>) {
        usuarioLogado = Map<String, dynamic>.from(respostaJson['dados']);
        await SessaoService.salvar(token, usuarioLogado!);

        return {
          'sucesso': true,
          'mensagem': respostaJson['mensagem'],
          'dados': usuarioLogado,
        };
      }

      return {
        'sucesso': false,
        'mensagem':
            respostaJson['mensagem'] ??
            respostaJson['message'] ??
            'Erro ao atualizar perfil',
      };
    } catch (erro) {
      return {
        'sucesso': false,
        'mensagem': 'Não foi possível conectar ao servidor',
      };
    }
  }

  static Future<Map<String, dynamic>> atualizarFotoPerfil(
    String caminhoFoto,
  ) async {
    final token = tokenUsuarioLogado;

    if (token == null) {
      return {'sucesso': false, 'mensagem': 'Usuário não está logado'};
    }

    try {
      final requisicao = http.MultipartRequest(
        'PATCH',
        Uri.parse('${ApiConfig.baseUrl}/usuarios/perfil/foto'),
      );

      requisicao.headers['Authorization'] = 'Bearer $token';
      requisicao.files.add(
        await http.MultipartFile.fromPath('foto', caminhoFoto),
      );

      final respostaStream = await requisicao.send();
      final resposta = await http.Response.fromStream(respostaStream);
      final Map<String, dynamic> respostaJson = resposta.body.isNotEmpty
          ? jsonDecode(resposta.body)
          : {};

      if (resposta.statusCode == 200 &&
          respostaJson['dados'] is Map<String, dynamic>) {
        usuarioLogado = Map<String, dynamic>.from(respostaJson['dados']);
        await SessaoService.salvar(token, usuarioLogado!);

        return {
          'sucesso': true,
          'mensagem': respostaJson['mensagem'],
          'dados': usuarioLogado,
        };
      }

      return {
        'sucesso': false,
        'mensagem':
            respostaJson['mensagem'] ??
            respostaJson['message'] ??
            'Erro ao atualizar foto',
      };
    } catch (erro) {
      return {'sucesso': false, 'mensagem': 'Não foi possível enviar a foto'};
    }
  }
}
