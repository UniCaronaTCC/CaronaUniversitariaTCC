import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/api_config.dart';
import '../models/conversa.dart';
import '../models/mensagem.dart';
import 'auth_service.dart';

class MensagemService {
  const MensagemService._();

  static Future<Map<String, dynamic>> listarConversas() async {
    return _requisicao(
      () => http.get(
        Uri.parse('${ApiConfig.baseUrl}/conversas'),
        headers: _cabecalhos(),
      ),
      converterDados: (dados) => _converterLista(dados, Conversa.fromJson),
    );
  }

  static Future<Map<String, dynamic>> obterConversa(
    int idSolicitacao,
  ) async {
    return _requisicao(
      () => http.post(
        Uri.parse(
          '${ApiConfig.baseUrl}/solicitacoes/$idSolicitacao/conversa',
        ),
        headers: _cabecalhos(),
      ),
      converterDados: (dados) => Conversa.fromJson(
        Map<String, dynamic>.from(dados as Map),
      ),
    );
  }

  static Future<Map<String, dynamic>> listarMensagens(
    int idConversa, {
    int? antesDe,
  }) async {
    final parametros = antesDe == null ? '' : '?antesDe=$antesDe';

    return _requisicao(
      () => http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/conversas/$idConversa/mensagens$parametros',
        ),
        headers: _cabecalhos(),
      ),
      converterDados: (dados) => _converterLista(dados, Mensagem.fromJson),
    );
  }

  static Future<Map<String, dynamic>> enviarMensagem(
    int idConversa,
    String conteudo,
  ) async {
    return _requisicao(
      () => http.post(
        Uri.parse(
          '${ApiConfig.baseUrl}/conversas/$idConversa/mensagens',
        ),
        headers: _cabecalhos(comJson: true),
        body: jsonEncode({'conteudo': conteudo}),
      ),
      converterDados: (dados) => Mensagem.fromJson(
        Map<String, dynamic>.from(dados as Map),
      ),
    );
  }

  static Future<RealtimeChannel?> acompanharConversa(
    int idConversa,
    void Function() aoReceberMensagem,
  ) async {
    final token = AuthService.tokenUsuarioLogado;

    if (token == null) {
      return null;
    }

    final cliente = Supabase.instance.client;
    await cliente.realtime.setAuth(token);

    return cliente
        .channel(
          'conversa:$idConversa',
          opts: const RealtimeChannelConfig(private: true),
        )
        .onBroadcast(event: 'INSERT', callback: (_) => aoReceberMensagem())
        .subscribe();
  }

  static Future<void> pararAcompanhamento(RealtimeChannel? canal) async {
    if (canal != null) {
      await Supabase.instance.client.removeChannel(canal);
    }
  }

  static Map<String, String> _cabecalhos({bool comJson = false}) {
    final token = AuthService.tokenUsuarioLogado;

    return {
      if (comJson) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> _requisicao(
    Future<http.Response> Function() enviar, {
    required dynamic Function(dynamic dados) converterDados,
  }) async {
    if (AuthService.tokenUsuarioLogado == null) {
      return {'sucesso': false, 'mensagem': 'Usuário não está logado'};
    }

    try {
      final resposta = await enviar();
      final corpo = resposta.body.isEmpty
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(jsonDecode(resposta.body) as Map);

      if (resposta.statusCode >= 200 && resposta.statusCode < 300) {
        return {
          'sucesso': true,
          'mensagem': corpo['mensagem'],
          'dados': converterDados(corpo['dados']),
        };
      }

      if (resposta.statusCode == 401) {
        await AuthService.sair();
      }

      return {
        'sucesso': false,
        'mensagem':
            corpo['mensagem']?.toString() ??
            corpo['message']?.toString() ??
            'Não foi possível concluir a operação',
      };
    } catch (erro) {
      return {
        'sucesso': false,
        'mensagem': 'Não foi possível conectar ao servidor',
      };
    }
  }

  static List<T> _converterLista<T>(
    dynamic dados,
    T Function(Map<String, dynamic>) converter,
  ) {
    if (dados is! List) {
      return <T>[];
    }

    return dados
        .whereType<Map>()
        .map((item) => converter(Map<String, dynamic>.from(item)))
        .toList();
  }
}
