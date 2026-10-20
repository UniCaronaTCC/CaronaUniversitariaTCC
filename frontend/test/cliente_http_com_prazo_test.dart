import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:uni_carona/services/cliente_http_com_prazo.dart';

class ClienteControlado extends http.BaseClient {
  final Future<http.StreamedResponse> Function() responder;
  bool fechado = false;

  ClienteControlado(this.responder);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => responder();

  @override
  void close() => fechado = true;
}

void main() {
  test('preserva corpo, status e cabecalhos e fecha conexao', () async {
    final origem = ClienteControlado(
      () async => http.StreamedResponse(
        Stream.value(utf8.encode('{"ok":true}')),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );
    final cliente = ClienteHttpComPrazo(criarCliente: () => origem);
    final resposta = await cliente.get(Uri.parse('https://example.test'));
    expect(resposta.body, '{"ok":true}');
    expect(resposta.statusCode, 200);
    expect(resposta.headers['content-type'], 'application/json');
    expect(origem.fechado, isTrue);
    cliente.close();
  });

  for (final corpoPendente in [false, true]) {
    test(
      'prazo abrange ${corpoPendente ? 'corpo' : 'cabecalhos'} pendentes',
      () async {
        final corpo = StreamController<List<int>>();
        final origem = ClienteControlado(
          () => corpoPendente
              ? Future.value(http.StreamedResponse(corpo.stream, 200))
              : Completer<http.StreamedResponse>().future,
        );
        final cliente = ClienteHttpComPrazo(
          prazo: const Duration(milliseconds: 10),
          criarCliente: () => origem,
        );
        await expectLater(
          cliente.get(Uri.parse('https://example.test')),
          throwsA(isA<TimeoutException>()),
        );
        expect(origem.fechado, isTrue);
        cliente.close();
        if (corpoPendente) {
          corpo.add([]);
          await corpo.close();
        } else {
          unawaited(corpo.close());
        }
      },
    );
  }

  test('fechar impede novas requisicoes', () async {
    final cliente = ClienteHttpComPrazo()..close();
    await expectLater(
      cliente.get(Uri.parse('https://example.test')),
      throwsA(isA<http.ClientException>()),
    );
  });
}
