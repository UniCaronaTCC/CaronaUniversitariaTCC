import 'dart:async';

import 'package:http/http.dart' as http;

/// Limita o recebimento completo e fecha a conexao que ultrapassou o prazo.
class ClienteHttpComPrazo extends http.BaseClient {
  final Duration prazo;
  final http.Client Function() criarCliente;
  final _ativos = <http.Client>{};
  bool _fechado = false;

  ClienteHttpComPrazo({
    this.prazo = const Duration(seconds: 20),
    http.Client Function()? criarCliente,
  }) : criarCliente = criarCliente ?? http.Client.new;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_fechado) throw http.ClientException('Cliente fechado');
    final cliente = criarCliente();
    _ativos.add(cliente);
    try {
      final resposta = await (() async {
        final stream = await cliente.send(request);
        return http.Response.fromStream(stream);
      })().timeout(prazo);
      return http.StreamedResponse(
        Stream.value(resposta.bodyBytes),
        resposta.statusCode,
        headers: resposta.headers,
        contentLength: resposta.bodyBytes.length,
        request: resposta.request,
        isRedirect: resposta.isRedirect,
        persistentConnection: resposta.persistentConnection,
        reasonPhrase: resposta.reasonPhrase,
      );
    } finally {
      _ativos.remove(cliente);
      cliente.close();
    }
  }

  @override
  void close() {
    _fechado = true;
    for (final cliente in _ativos.toList()) {
      cliente.close();
    }
    _ativos.clear();
  }
}
