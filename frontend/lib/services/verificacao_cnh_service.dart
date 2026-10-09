import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';

class VerificacaoCnhService {
  final http.Client? cliente;
  final Duration prazo;

  const VerificacaoCnhService({
    this.cliente,
    this.prazo = const Duration(seconds: 90),
  });

  Future<Map<String, dynamic>> enviar(
    Uint8List frente,
    Uint8List verso, {
    required bool aceitePrivacidade,
  }) async {
    if (!aceitePrivacidade) {
      return {'sucesso': false, 'mensagem': 'Aceite o aviso de privacidade'};
    }
    if (frente.isEmpty ||
        verso.isEmpty ||
        frente.length > 5 * 1024 * 1024 ||
        verso.length > 5 * 1024 * 1024) {
      return {
        'sucesso': false,
        'mensagem': 'Envie duas fotos de até 5 MB cada',
      };
    }

    final conexao = cliente ?? http.Client();
    try {
      final resposta = await AuthService.enviarComToken((token) async {
        final pedido =
            http.MultipartRequest(
                'POST',
                Uri.parse('${ApiConfig.baseUrl}/usuarios/cnh/verificar'),
              )
              ..headers['Authorization'] = 'Bearer $token'
              ..fields['aceitePrivacidade'] = 'true'
              ..files.addAll([
                http.MultipartFile.fromBytes(
                  'frente',
                  frente,
                  filename: 'frente.jpg',
                ),
                http.MultipartFile.fromBytes(
                  'verso',
                  verso,
                  filename: 'verso.jpg',
                ),
              ]);
        return http.Response.fromStream(await conexao.send(pedido));
      }).timeout(prazo);

      if (resposta == null) {
        return {'sucesso': false, 'mensagem': 'Usuário não está logado'};
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
    } on TimeoutException {
      return {
        'sucesso': false,
        'mensagem':
            'A verificação demorou. Atualize o status antes de tentar novamente',
      };
    } catch (_) {
      return {
        'sucesso': false,
        'mensagem': 'Não foi possível conectar ao servidor. Tente novamente',
      };
    } finally {
      if (cliente == null) conexao.close();
    }
  }
}
