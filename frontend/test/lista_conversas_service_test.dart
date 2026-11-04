import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uni_carona/models/conversa.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/services/mensagem_service.dart';

import 'conversa_estado_test.dart' show conversaJson;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    AuthService.usuarioLogado = {'id': 1};
    AuthService.tokenUsuarioLogado = 'token-sintetico';
  });
  tearDown(() {
    AuthService.usuarioLogado = null;
    AuthService.tokenUsuarioLogado = null;
  });

  Future<Map<String, dynamic>> consultar(String body, [int status = 200]) =>
      http.runWithClient(
        MensagemService.listarConversas,
        () => MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/conversas');
          expect(request.headers['Authorization'], 'Bearer token-sintetico');
          return http.Response(body, status);
        }),
      );

  test('lista completa conserva status, mensagem e contagem', () async {
    final dados = conversaJson('ATIVA')..['mensagensNaoLidas'] = 3;
    final resposta = await consultar(
      jsonEncode({
        'sucesso': true,
        'dados': [dados],
      }),
    );
    expect(resposta['sucesso'], isTrue);
    final lista = resposta['dados'] as List<Conversa>;
    expect(lista.single.mensagensNaoLidas, 3);
    expect(lista.single.statusCarona, 'ATIVA');
  });

  test('lista vazia explicita e valida', () async {
    final resposta = await consultar('{"sucesso":true,"dados":[]}');
    expect(resposta['sucesso'], isTrue);
    expect(resposta['dados'], isEmpty);
  });

  for (final body in [
    '',
    '<html>indisponivel</html>',
    '{',
    '[]',
    'null',
    '{}',
    '{"sucesso":false,"dados":[]}',
    '{"sucesso":true}',
    '{"sucesso":true,"dados":null}',
    '{"sucesso":true,"dados":{}}',
    '{"sucesso":true,"dados":[null]}',
    '{"sucesso":true,"dados":[{}]}',
  ]) {
    test('nao converte resposta invalida em sucesso vazio: $body', () async {
      expect((await consultar(body))['sucesso'], isFalse);
    });
  }

  test('item invalido nao produz lista parcial', () async {
    final resposta = await consultar(
      jsonEncode({
        'sucesso': true,
        'dados': [conversaJson('ATIVA'), null],
      }),
    );
    expect(resposta['sucesso'], isFalse);
  });

  test('401 mesmo em HTML encerra sessao e nao vira cache vazio', () async {
    final resposta = await consultar('<html>Unauthorized</html>', 401);
    expect(resposta['sucesso'], isFalse);
    expect(AuthService.estaLogado, isFalse);
    expect(AuthService.usuarioLogado, isNull);
  });

  test('falha de rede nao encerra sessao', () async {
    final resposta = await http.runWithClient(
      MensagemService.listarConversas,
      () => MockClient((_) async => throw http.ClientException('offline')),
    );
    expect(resposta['sucesso'], isFalse);
    expect(AuthService.estaLogado, isTrue);
  });

  testWidgets('limita espera da lista sem alterar a sessao', (tester) async {
    final atrasada = Completer<http.Response>();
    final pendente = http.runWithClient(
      MensagemService.listarConversas,
      () => MockClient((_) => atrasada.future),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 21));
    expect((await pendente)['sucesso'], isFalse);
    expect(AuthService.estaLogado, isTrue);
    atrasada.complete(http.Response('{"sucesso":true,"dados":[]}', 200));
    await tester.pump();
  });
}
