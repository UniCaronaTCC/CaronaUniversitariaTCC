import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/api_config.dart';
import 'sessao_service.dart';
import 'supabase_auth_service.dart';

class AuthService {
  static String? _tokenUsuarioLogado;
  static Map<String, dynamic>? usuarioLogado;
  static int _versaoSessao = 0;

  static String? get tokenUsuarioLogado =>
      SupabaseAuthService.tokenAtual ?? _tokenUsuarioLogado;

  static set tokenUsuarioLogado(String? token) {
    if (token == null) _versaoSessao++;
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
    _versaoSessao++;
    try {
      await SupabaseAuthService.sair();
    } finally {
      tokenUsuarioLogado = null;
      usuarioLogado = null;
      await SessaoService.limpar();
    }
  }

  static Future<String?> renovarSessao() async {
    final versao = _versaoSessao;
    final novoToken = await SupabaseAuthService.renovarSessao();

    if (versao != _versaoSessao) return null;

    if (novoToken == null) {
      return null;
    }

    tokenUsuarioLogado = novoToken;

    final usuario = usuarioLogado;
    if (usuario != null) {
      await SessaoService.salvar(novoToken, usuario);
    }

    return novoToken;
  }

  static Future<http.Response?> enviarComToken(
    Future<http.Response> Function(String token) enviar,
  ) async {
    final versao = _versaoSessao;
    final token = tokenUsuarioLogado;

    if (token == null) {
      return null;
    }

    var resposta = await enviar(token);

    if (versao != _versaoSessao) return null;

    if (resposta.statusCode != 401) {
      return resposta;
    }

    final novoToken = await renovarSessao();
    if (versao != _versaoSessao) return null;
    if (novoToken == null) {
      return resposta;
    }

    resposta = await enviar(novoToken);
    return versao == _versaoSessao ? resposta : null;
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
      _versaoSessao++;
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
    } on TimeoutException {
      return {
        'sucesso': false,
        'mensagem': 'O acesso demorou demais. Tente novamente',
      };
    } on AuthException catch (erro) {
      return {'sucesso': false, 'mensagem': _mensagemErroSupabase(erro)};
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
      return {'sucesso': false, 'mensagem': _mensagemErroSupabase(erro)};
    } catch (erro) {
      return {
        'sucesso': false,
        'mensagem': 'Não foi possível conectar ao serviço de cadastro',
      };
    }
  }

  static String _mensagemErroSupabase(AuthException erro) {
    if (erro is AuthRetryableFetchException) {
      return 'Não foi possível acessar o serviço agora. Confira a conexão e tente novamente';
    }
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

  static Future<Map<String, dynamic>> buscarPerfil({
    Duration prazo = const Duration(seconds: 20),
  }) {
    return _requisicaoPerfil(
      (cliente, token) => cliente.get(
        Uri.parse('${ApiConfig.baseUrl}/usuarios/perfil'),
        headers: {'Authorization': 'Bearer $token'},
      ),
      prazo: prazo,
    );
  }

  static Future<Map<String, dynamic>> atualizarPerfil(
    int idInstituicao,
    String campus,
  ) {
    return _requisicaoPerfil(
      (cliente, token) => cliente.patch(
        Uri.parse('${ApiConfig.baseUrl}/usuarios/perfil'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'idInstituicao': idInstituicao, 'campus': campus}),
      ),
      alteracao: true,
    );
  }

  static Future<Map<String, dynamic>> atualizarFotoPerfil(String caminhoFoto) {
    return _requisicaoPerfil(
      (cliente, token) async {
        final requisicao = http.MultipartRequest(
          'PATCH',
          Uri.parse('${ApiConfig.baseUrl}/usuarios/perfil/foto'),
        );

        requisicao.headers['Authorization'] = 'Bearer $token';
        requisicao.files.add(
          await http.MultipartFile.fromPath('foto', caminhoFoto),
        );

        return http.Response.fromStream(await cliente.send(requisicao));
      },
      alteracao: true,
      prazo: const Duration(seconds: 45),
    );
  }

  static Future<Map<String, dynamic>> salvarVeiculo(
    String modelo,
    String cor,
    String placa,
  ) {
    return _requisicaoPerfil(
      (cliente, token) => cliente.put(
        Uri.parse('${ApiConfig.baseUrl}/usuarios/perfil/veiculo'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'modelo': modelo, 'cor': cor, 'placa': placa}),
      ),
      alteracao: true,
      veiculo: true,
    );
  }

  static Future<Map<String, dynamic>> _requisicaoPerfil(
    Future<http.Response> Function(http.Client cliente, String token) enviar, {
    Duration prazo = const Duration(seconds: 20),
    bool alteracao = false,
    bool veiculo = false,
  }) async {
    final cliente = http.Client();
    final versao = _versaoSessao;
    var encerrada = false;
    Map<String, dynamic> falha(String mensagem) => {
      'sucesso': false,
      'mensagem': mensagem,
    };
    try {
      final resposta = await enviarComToken((token) {
        // Um refresh tardio nao deve reenviar uma operacao cujo prazo acabou.
        if (encerrada) throw TimeoutException('Requisicao encerrada');
        return enviar(cliente, token);
      }).timeout(prazo);
      if (resposta == null || versao != _versaoSessao) {
        return falha('Usuário não está logado');
      }
      if (resposta.statusCode == 401) {
        await sair();
        return falha('Sua sessão expirou. Entre novamente');
      }
      Map<String, dynamic>? corpo;
      try {
        final json = jsonDecode(resposta.body);
        if (json is Map<String, dynamic>) corpo = json;
      } on FormatException {
        // Proxies podem responder HTML; o status HTTP ainda deve ser tratado.
      }
      if (resposta.statusCode >= 500) {
        return falha(
          'O servidor está indisponível no momento. Tente novamente',
        );
      }
      if (resposta.statusCode == 429) {
        return falha('Aguarde um pouco antes de tentar novamente');
      }
      if (resposta.statusCode != 200) {
        final mensagem = corpo?['mensagem'] ?? corpo?['message'];
        final resultado = falha(
          mensagem is List
              ? mensagem.join('\n')
              : mensagem?.toString() ?? 'Não foi possível concluir a operação',
        );
        if (veiculo && corpo?['campos'] is Map) {
          resultado['campos'] = corpo!['campos'];
        }
        return resultado;
      }
      final dados = corpo?['dados'];
      if (dados is! Map<String, dynamic>) {
        return falha(
          'O servidor retornou uma resposta inválida. Tente novamente',
        );
      }
      final perfil = veiculo
          ? (usuarioLogado == null
                ? null
                : {...usuarioLogado!, 'veiculo': dados})
          : Map<String, dynamic>.from(dados);
      if (perfil != null) {
        usuarioLogado = perfil;
        await SessaoService.salvar(tokenUsuarioLogado!, perfil);
      }
      return {'sucesso': true, 'dados': dados, 'mensagem': corpo?['mensagem']};
    } on TimeoutException {
      return falha(
        alteracao
            ? 'Não foi possível confirmar a alteração a tempo. Atualize o perfil antes de tentar novamente'
            : 'O servidor demorou para responder. Tente novamente',
      );
    } on AuthException {
      return falha(
        'Não foi possível renovar o acesso agora. Confira a conexão e tente novamente',
      );
    } catch (_) {
      return {
        'sucesso': false,
        'mensagem': alteracao
            ? 'Não foi possível confirmar a alteração. Confira a conexão e atualize o perfil antes de tentar novamente'
            : 'Não foi possível conectar ao servidor. Confira a conexão e tente novamente',
      };
    } finally {
      encerrada = true;
      cliente.close();
    }
  }
}
