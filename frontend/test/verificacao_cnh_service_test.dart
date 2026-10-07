import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/services/verificacao_cnh_service.dart';

void main() {
  final frente = Uint8List.fromList([1, 2, 3]);
  final verso = Uint8List.fromList([4, 5, 6]);
  setUp(() => AuthService.tokenUsuarioLogado = 'token-teste');
  tearDown(() => AuthService.tokenUsuarioLogado = null);

  test('envia fotos e aceite ao backend com o token', () async {
    late http.Request recebido;
    final service = VerificacaoCnhService(
      cliente: MockClient((pedido) async {
        recebido = pedido;
        return http.Response(
          jsonEncode({
            'dados': {'status': 'APROVADA'},
          }),
          201,
        );
      }),
    );
    final resultado = await service.enviar(
      frente,
      verso,
      aceitePrivacidade: true,
    );
    expect(resultado['dados']['status'], 'APROVADA');
    expect(recebido.url.path, '/usuarios/cnh/verificar');
    expect(recebido.headers['authorization'], 'Bearer token-teste');
    expect(recebido.headers['content-type'], startsWith('multipart/form-data'));
    expect(recebido.body, contains('name="aceitePrivacidade"'));
    expect(recebido.body, contains('name="frente"'));
    expect(recebido.body, contains('name="verso"'));
    expect(recebido.bodyBytes, containsAllInOrder(frente));
    expect(recebido.bodyBytes, containsAllInOrder(verso));
  });

  test('não envia sem aceite, fotos ou sessão', () async {
    var chamadas = 0;
    final service = VerificacaoCnhService(
      cliente: MockClient((_) async {
        chamadas++;
        return http.Response('{}', 500);
      }),
    );
    expect(
      (await service.enviar(
        frente,
        verso,
        aceitePrivacidade: false,
      ))['sucesso'],
      isFalse,
    );
    expect(
      (await service.enviar(
        Uint8List(0),
        verso,
        aceitePrivacidade: true,
      ))['sucesso'],
      isFalse,
    );
    expect(
      (await service.enviar(
        Uint8List(5 * 1024 * 1024 + 1),
        verso,
        aceitePrivacidade: true,
      ))['sucesso'],
      isFalse,
    );
    AuthService.tokenUsuarioLogado = null;
    expect(
      (await service.enviar(
        frente,
        verso,
        aceitePrivacidade: true,
      ))['mensagem'],
      'Usuário não está logado',
    );
    expect(chamadas, 0);
  });

  test(
    'recusa é um resultado processado e erros de servidor permitem tentar novamente',
    () async {
      final recusada = VerificacaoCnhService(
        cliente: MockClient(
          (_) async => http.Response('{"dados":{"status":"RECUSADA"}}', 201),
        ),
      );
      expect(
        (await recusada.enviar(
          frente,
          verso,
          aceitePrivacidade: true,
        ))['dados']['status'],
        'RECUSADA',
      );
      final falha = VerificacaoCnhService(
        cliente: MockClient(
          (_) async => http.Response(
            '{"message":"Serviço temporariamente indisponível"}',
            503,
          ),
        ),
      );
      expect(
        (await falha.enviar(
          frente,
          verso,
          aceitePrivacidade: true,
        ))['mensagem'],
        'Serviço temporariamente indisponível',
      );
    },
  );

  test('limita a espera e permite consultar se o servidor concluiu', () async {
    final pendente = Completer<http.Response>();
    final service = VerificacaoCnhService(
      prazo: const Duration(milliseconds: 1),
      cliente: MockClient((_) => pendente.future),
    );
    final resultado = await service.enviar(
      frente,
      verso,
      aceitePrivacidade: true,
    );
    expect(resultado['sucesso'], isFalse);
    expect(resultado['mensagem'], contains('Atualize o status'));
    pendente.complete(http.Response('{}', 500));
  });
}
