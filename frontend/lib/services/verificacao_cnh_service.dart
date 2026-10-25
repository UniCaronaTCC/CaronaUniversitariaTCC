import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';
import 'sessao_service.dart';
import 'ocr_cnh_service.dart';

class VerificacaoCnhService {
  final http.Client? cliente;
  final LerCnh? lerCnh;
  final Duration prazo;
  final void Function(String)? registrarDiagnostico;

  const VerificacaoCnhService({
    this.cliente,
    this.lerCnh,
    this.prazo = const Duration(seconds: 90),
    this.registrarDiagnostico,
  });

  Future<Map<String, dynamic>> buscarDadosExtraidos() async {
    final conexao = cliente ?? http.Client();
    try {
      final resposta = await AuthService.enviarComToken(
        (token) => conexao.get(
          Uri.parse('${ApiConfig.baseUrl}/usuarios/cnh/dados'),
          headers: {'Authorization': 'Bearer $token'},
        ),
      ).timeout(const Duration(seconds: 15));
      if (resposta == null || resposta.statusCode != 200) return {};
      final corpo = jsonDecode(resposta.body);
      if (corpo is! Map || corpo['dados'] is! Map) return {};
      return Map<String, dynamic>.from(corpo['dados']);
    } catch (_) {
      return {};
    } finally {
      if (cliente == null) conexao.close();
    }
  }

  void _diagnosticar(String mensagem) {
    if (!kDebugMode) return;
    final registrar = registrarDiagnostico;
    if (registrar != null) {
      registrar('CNH_ENVIO $mensagem');
    } else {
      debugPrint('CNH_ENVIO $mensagem');
    }
  }

  String _formatoResposta(Map<String, String> headers) {
    final tipo = headers['content-type']?.split(';').first.trim().toLowerCase();
    if (tipo == 'application/json' || (tipo?.endsWith('+json') ?? false)) {
      return 'json';
    }
    if (tipo == 'text/html') return 'html';
    if (tipo == 'text/plain') return 'texto';
    return tipo == null ? 'ausente' : 'outro';
  }

  String _causaConexao(http.ClientException erro) {
    // Classifica a mensagem, mas nunca a imprime: ela pode conter a URI.
    final texto = erro.message.toLowerCase();
    if (texto.contains('failed host lookup') ||
        texto.contains('name or service not known') ||
        texto.contains('no address associated with hostname')) {
      return 'dns';
    }
    if (texto.contains('connection refused')) return 'conexao_recusada';
    if (texto.contains('connection reset') || texto.contains('broken pipe')) {
      return 'conexao_interrompida';
    }
    if (texto.contains('connection closed')) return 'conexao_fechada';
    if (texto.contains('network is unreachable') ||
        texto.contains('no route to host')) {
      return 'rede_inacessivel';
    }
    if (texto.contains('timed out')) return 'timeout_socket';
    return 'nao_classificada';
  }

  Future<Map<String, dynamic>> reiniciarTeste() async {
    final conexao = cliente ?? http.Client();
    try {
      final resposta = await AuthService.enviarComToken(
        (token) => conexao.post(
          Uri.parse('${ApiConfig.baseUrl}/usuarios/cnh/reiniciar-teste'),
          headers: {'Authorization': 'Bearer $token'},
        ),
      ).timeout(const Duration(seconds: 15));
      if (resposta == null) {
        return {'sucesso': false, 'mensagem': 'Usuário não está logado'};
      }
      final corpo = jsonDecode(resposta.body);
      if (corpo is! Map) throw const FormatException();
      if (resposta.statusCode >= 200 &&
          resposta.statusCode < 300 &&
          corpo['dados'] is Map &&
          corpo['dados']['status'] == 'NAO_ENVIADA') {
        final perfil = AuthService.usuarioLogado;
        if (perfil != null) {
          AuthService.usuarioLogado = {
            ...perfil,
            'statusVerificacaoCnh': 'NAO_ENVIADA',
            'cnhCategoria': null,
            'cnhValidade': null,
          };
          final token = AuthService.tokenUsuarioLogado;
          if (token != null) {
            await SessaoService.salvar(token, AuthService.usuarioLogado!);
          }
        }
        return {'sucesso': true};
      }
      return {
        'sucesso': false,
        'mensagem':
            corpo['message']?.toString() ??
            corpo['mensagem']?.toString() ??
            'Não foi possível reiniciar a CNH',
      };
    } catch (_) {
      return {
        'sucesso': false,
        'mensagem':
            'Não foi possível confirmar o reinício. Atualize o status antes de tentar novamente',
      };
    } finally {
      if (cliente == null) conexao.close();
    }
  }

  Future<Map<String, dynamic>> enviar(
    Uint8List frente, {
    required bool aceitePrivacidade,
  }) async {
    if (!aceitePrivacidade) {
      return {'sucesso': false, 'mensagem': 'Aceite o aviso de privacidade'};
    }
    if (frente.isEmpty || frente.length > 5 * 1024 * 1024) {
      return {
        'sucesso': false,
        'mensagem': 'Envie uma foto de até 5 MB da frente da CNH',
      };
    }
    if (AuthService.tokenUsuarioLogado == null) {
      return {'sucesso': false, 'mensagem': 'Usuário não está logado'};
    }
    final Map<String, dynamic> leitura;
    try {
      leitura = await (lerCnh ?? lerCnhNoCelular)(frente);
    } on UnsupportedError {
      return {
        'sucesso': false,
        'mensagem': 'Use Android ou iPhone para ler a CNH.',
      };
    } on FormatException catch (erro) {
      return {'sucesso': false, 'mensagem': erro.message};
    } catch (_) {
      return {
        'sucesso': false,
        'mensagem':
            'Não foi possível ler a foto no celular. Confira a orientação, os campos e tente novamente.',
      };
    }
    final conexao = cliente ?? http.Client();
    final relogio = Stopwatch()..start();
    var fase = 'preparacao';
    var tentativa = 0;
    int? statusHttp;
    var formato = 'sem_resposta';
    void registrarFalha(Object erro, String classe) {
      // Nunca registrar a mensagem da excecao, corpo, cabecalhos ou documentos.
      _diagnosticar(
        'falha classe=$classe tipo=${erro.runtimeType} fase=$fase '
        'http=${statusHttp ?? 'sem_resposta'} formato=$formato '
        'tempo_ms=${relogio.elapsedMilliseconds}',
      );
    }

    _diagnosticar('inicio');
    try {
      final resposta = await AuthService.enviarComToken((token) async {
        tentativa++;
        statusHttp = null;
        formato = 'sem_resposta';
        fase = 'preparacao';
        final pedido =
            http.Request(
                'POST',
                Uri.parse('${ApiConfig.baseUrl}/usuarios/cnh/verificar-mlkit'),
              )
              ..headers.addAll({
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              })
              ..body = jsonEncode({
                'versaoLeitura': 'mlkit-v1',
                'aceitePrivacidade': true,
                'leitura': leitura,
              });
        fase = 'aguardando_resposta';
        _diagnosticar('requisicao tentativa=$tentativa');
        final recebida = await conexao.send(pedido);
        statusHttp = recebida.statusCode;
        formato = _formatoResposta(recebida.headers);
        _diagnosticar(
          'resposta http=$statusHttp formato=$formato '
          'tempo_ms=${relogio.elapsedMilliseconds}',
        );
        fase = 'lendo_resposta';
        return http.Response.fromStream(recebida);
      }).timeout(prazo);

      if (resposta == null) {
        _diagnosticar('sem_sessao');
        return {'sucesso': false, 'mensagem': 'Usuário não está logado'};
      }
      fase = 'interpretando_resposta';
      if (resposta.statusCode == 404) {
        return {
          'sucesso': false,
          'mensagem':
              'O servidor ainda não está atualizado para o novo leitor de CNH. Publique o backend atualizado antes de tentar novamente.',
        };
      }
      final corpo = jsonDecode(resposta.body);
      if (corpo is! Map) throw const FormatException();
      final dados = corpo['dados'];
      if (resposta.statusCode >= 200 &&
          resposta.statusCode < 300 &&
          dados is Map &&
          ['APROVADA', 'RECUSADA'].contains(dados['status'])) {
        return {
          'sucesso': true,
          'dados': Map<String, dynamic>.from(dados),
          'mensagem': corpo['mensagem'],
        };
      }
      final mensagem = corpo['mensagem'] ?? corpo['message'];
      return {
        'sucesso': false,
        'mensagem': mensagem is List
            ? mensagem.join('\n')
            : mensagem?.toString() ?? 'Não foi possível conferir a CNH',
      };
    } on TimeoutException catch (erro) {
      registrarFalha(erro, 'timeout');
      return {
        'sucesso': false,
        'mensagem':
            'A verificação demorou. Atualize o status antes de tentar novamente',
      };
    } on FormatException catch (erro) {
      registrarFalha(erro, 'resposta_invalida');
      return {
        'sucesso': false,
        'mensagem':
            'O servidor retornou uma resposta inválida'
            '${statusHttp == null ? '' : ' (HTTP $statusHttp)'}. '
            'Atualize o status antes de tentar novamente',
      };
    } on http.ClientException catch (erro) {
      registrarFalha(erro, 'conexao');
      _diagnosticar('conexao causa=${_causaConexao(erro)}');
      return {
        'sucesso': false,
        'mensagem':
            'Falha de conexão ao enviar a CNH. Confira a internet e tente novamente',
      };
    } catch (erro) {
      registrarFalha(erro, 'inesperada');
      return {
        'sucesso': false,
        'mensagem': 'Não foi possível concluir o envio da CNH. Tente novamente',
      };
    } finally {
      relogio.stop();
      if (cliente == null) conexao.close();
    }
  }
}
