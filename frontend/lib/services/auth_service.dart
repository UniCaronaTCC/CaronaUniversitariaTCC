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

      if (sessao == null && tokenSupabase == null) {
        tokenUsuarioLogado = null;
        usuarioLogado = null;
        return;
      }

      tokenUsuarioLogado = tokenSupabase ?? sessao?['token']?.toString();
      usuarioLogado = sessao?['usuario'] as Map<String, dynamic>?;

      if (tokenSupabase != null) {
        await buscarPerfil();
      }
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
    if (SupabaseAuthService.configurado) {
      try {
        final resposta = await SupabaseAuthService.entrar(email, senha);
        tokenUsuarioLogado = resposta.session?.accessToken;

        if (tokenUsuarioLogado != null) {
          final perfil = await buscarPerfil();

          if (perfil['sucesso'] == true) {
            return {
              'sucesso': true,
              'dados': {
                'mensagem': 'Login realizado com sucesso',
                'usuario': perfil['dados'],
              },
            };
          }

          return perfil;
        }

        return {
          'sucesso': false,
          'mensagem': 'Confirme seu e-mail antes de entrar',
        };
      } on AuthException catch (erro) {
        if (erro.message.toLowerCase().contains('email not confirmed')) {
          return {
            'sucesso': false,
            'mensagem': 'Confirme seu e-mail antes de entrar',
          };
        }

        // Usuários antigos ainda entram pelo login do backend.
      }
    }

    return _fazerLoginAntigo(email, senha);
  }

  static Future<Map<String, dynamic>> _fazerLoginAntigo(
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
    if (SupabaseAuthService.configurado) {
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
          'mensagem': _mensagemErroSupabase(erro.message),
        };
      } catch (erro) {
        return {
          'sucesso': false,
          'mensagem': 'Não foi possível conectar ao serviço de cadastro',
        };
      }
    }

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

  static String _mensagemErroSupabase(String mensagem) {
    final texto = mensagem.toLowerCase();

    if (texto.contains('already registered') ||
        texto.contains('already been registered')) {
      return 'Este e-mail já está cadastrado';
    }

    if (texto.contains('password')) {
      return 'A senha não atende aos requisitos de segurança';
    }

    if (texto.contains('rate limit')) {
      return 'Aguarde um pouco antes de tentar novamente';
    }

    return mensagem;
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
