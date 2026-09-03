import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uni_carona/models/pagamento_pix.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/services/pagamento_service.dart';

void main() {
  tearDown(() {
    AuthService.tokenUsuarioLogado = null;
  });

  test('chama somente o backend com o token e converte o Pix', () async {
    AuthService.tokenUsuarioLogado = 'token-teste';
    late http.Request requisicaoRecebida;
    final service = PagamentoService(
      cliente: MockClient((requisicao) async {
        requisicaoRecebida = requisicao;
        return http.Response(
          jsonEncode({
            'sucesso': true,
            'dados': {
              'id': 30,
              'idSolicitacao': 10,
              'metodo': 'PIX',
              'valorCentavos': 1250,
              'statusCriacao': 'CONFIRMADA',
              'status': 'PENDING',
              'pixCopiaECola': 'codigo-pix',
              'qrCodeBase64': 'cXItZmljdGljaW8=',
              'expiraEm': '2026-09-04T12:00:00.000Z',
              'modoTeste': true,
            },
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final resultado = await service.criarOuObterPix(10);

    expect(resultado['sucesso'], isTrue);
    expect(resultado['dados'], isA<PagamentoPix>());
    expect(requisicaoRecebida.url.path, '/pagamentos/solicitacoes/10/pix');
    expect(requisicaoRecebida.method, 'POST');
    expect(requisicaoRecebida.headers['authorization'], 'Bearer token-teste');
    expect(requisicaoRecebida.body, isEmpty);
  });

  test('repassa ao usuario a mensagem segura do backend', () async {
    AuthService.tokenUsuarioLogado = 'token-teste';
    final service = PagamentoService(
      cliente: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'message': 'Pagamentos recorrentes ainda não estão disponíveis',
          }),
          409,
        ),
      ),
    );

    final resultado = await service.criarOuObterPix(10);

    expect(resultado['sucesso'], isFalse);
    expect(
      resultado['mensagem'],
      'Pagamentos recorrentes ainda não estão disponíveis',
    );
  });

  test('nao faz requisicao sem usuario autenticado', () async {
    var chamouBackend = false;
    final service = PagamentoService(
      cliente: MockClient((_) async {
        chamouBackend = true;
        return http.Response('{}', 200);
      }),
    );

    final resultado = await service.criarOuObterPix(10);

    expect(resultado['sucesso'], isFalse);
    expect(chamouBackend, isFalse);
  });
}
