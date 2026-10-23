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
  setUp(() => AuthService.tokenUsuarioLogado = 'token-teste');
  tearDown(() => AuthService.tokenUsuarioLogado = null);

  test(
    'servidor antigo orienta atualizar backend em vez de culpar o aceite',
    () async {
      final service = VerificacaoCnhService(
        lerCnh: (_) async => {'largura': 1000, 'altura': 800, 'linhas': []},
        cliente: MockClient((pedido) async {
          final corpo = jsonDecode(pedido.body) as Map;
          expect(corpo['aceitePrivacidade'], true);
          expect(pedido.url.path, '/usuarios/cnh/verificar-mlkit');
          return http.Response(
            '{"message":"Cannot POST /usuarios/cnh/verificar-mlkit"}',
            404,
          );
        }),
      );
      final resultado = await service.enviar(frente, aceitePrivacidade: true);
      expect(resultado['sucesso'], false);
      expect(resultado['mensagem'], contains('backend atualizado'));
    },
  );

  test('falha do leitor local não envia dados nem muda a conta', () async {
    var chamadas = 0;
    final service = VerificacaoCnhService(
      lerCnh: (_) async => throw StateError('erro do leitor'),
      cliente: MockClient((_) async {
        chamadas++;
        return http.Response('{}', 500);
      }),
    );
    final resultado = await service.enviar(frente, aceitePrivacidade: true);
    expect(resultado['sucesso'], false);
    expect(resultado['mensagem'], contains('no celular'));
    expect(chamadas, 0);
  });

  test('sem sessão ou aceite não inicia reconhecimento', () async {
    var leituras = 0;
    final service = VerificacaoCnhService(
      lerCnh: (_) async {
        leituras++;
        return {};
      },
    );
    await service.enviar(frente, aceitePrivacidade: false);
    AuthService.tokenUsuarioLogado = null;
    await service.enviar(frente, aceitePrivacidade: true);
    expect(leituras, 0);
  });

  for (final resposta in [
    http.Response(
      '<html>dado-sensivel-sintetico</html>',
      502,
      headers: {'content-type': 'text/html; charset=utf-8'},
    ),
    http.Response('', 503, headers: {'content-type': 'text/plain'}),
    http.Response(
      '["dado-sensivel-sintetico"]',
      200,
      headers: {'content-type': 'application/json'},
    ),
  ]) {
    test('diagnostica resposta invalida HTTP ${resposta.statusCode}', () async {
      final logs = <String>[];
      final service = VerificacaoCnhService(
        lerCnh: (_) async => {'largura': 1000, 'altura': 800, 'linhas': []},
        registrarDiagnostico: logs.add,
        cliente: MockClient((_) async => resposta),
      );
      final resultado = await service.enviar(frente, aceitePrivacidade: true);
      expect(resultado['sucesso'], false);
      expect(resultado['mensagem'], contains('HTTP ${resposta.statusCode}'));
      expect(resultado['mensagem'], isNot(contains('conectar')));
      final diagnostico = logs.join('\n');
      expect(diagnostico, contains('CNH_ENVIO inicio'));
      expect(diagnostico, contains('classe=resposta_invalida'));
      expect(diagnostico, contains('tipo=FormatException'));
      expect(diagnostico, contains('fase=interpretando_resposta'));
      expect(diagnostico, contains('http=${resposta.statusCode}'));
      expect(diagnostico, isNot(contains('dado-sensivel-sintetico')));
      expect(diagnostico, isNot(contains('Nome Sensivel')));
      expect(diagnostico, isNot(contains('token-teste')));
    });
  }

  test(
    'diagnostica falha de conexao sem imprimir mensagem da excecao',
    () async {
      final logs = <String>[];
      final service = VerificacaoCnhService(
        lerCnh: (_) async => {'largura': 1000, 'altura': 800, 'linhas': []},
        registrarDiagnostico: logs.add,
        cliente: MockClient((_) async {
          throw http.ClientException('dado-sensivel-sintetico token-teste');
        }),
      );
      final resultado = await service.enviar(frente, aceitePrivacidade: true);
      expect(resultado['mensagem'], contains('Falha de conexão'));
      final diagnostico = logs.join('\n');
      expect(diagnostico, contains('classe=conexao tipo=ClientException'));
      expect(diagnostico, contains('fase=aguardando_resposta'));
      expect(diagnostico, contains('http=sem_resposta'));
      expect(diagnostico, isNot(contains('dado-sensivel-sintetico')));
      expect(diagnostico, isNot(contains('token-teste')));
    },
  );

  test('falha inesperada nao e apresentada como falta de conexao', () async {
    final logs = <String>[];
    final service = VerificacaoCnhService(
      lerCnh: (_) async => {'largura': 1000, 'altura': 800, 'linhas': []},
      registrarDiagnostico: logs.add,
      cliente: MockClient(
        (_) async => throw StateError('dado-sensivel-sintetico'),
      ),
    );
    final resultado = await service.enviar(frente, aceitePrivacidade: true);
    expect(resultado['sucesso'], false);
    expect(resultado['mensagem'], contains('concluir o envio'));
    expect(logs.join('\n'), contains('classe=inesperada tipo=StateError'));
    expect(logs.join('\n'), isNot(contains('dado-sensivel-sintetico')));
  });

  for (final caso in <String, String>{
    "Failed host lookup: 'dado-sensivel-sintetico'": 'dns',
    'Connection refused dado-sensivel-sintetico': 'conexao_recusada',
    'Connection reset by peer dado-sensivel-sintetico': 'conexao_interrompida',
    'Connection closed before full header dado-sensivel-sintetico':
        'conexao_fechada',
    'Network is unreachable dado-sensivel-sintetico': 'rede_inacessivel',
    'Connection timed out dado-sensivel-sintetico': 'timeout_socket',
    'dado-sensivel-sintetico': 'nao_classificada',
  }.entries) {
    test('classifica conexao como ${caso.value} sem expor mensagem', () async {
      final logs = <String>[];
      final service = VerificacaoCnhService(
        lerCnh: (_) async => {'largura': 1000, 'altura': 800, 'linhas': []},
        registrarDiagnostico: logs.add,
        cliente: MockClient((_) async => throw http.ClientException(caso.key)),
      );
      await service.enviar(frente, aceitePrivacidade: true);
      expect(logs.join('\n'), contains('conexao causa=${caso.value}'));
      expect(logs.join('\n'), isNot(contains('dado-sensivel-sintetico')));
    });
  }

  test(
    'reinicia com um unico POST sem documento ou id de outra conta',
    () async {
      final pedidos = <http.Request>[];
      final service = VerificacaoCnhService(
        lerCnh: (_) async => {'largura': 1000, 'altura': 800, 'linhas': []},
        cliente: MockClient((r) async {
          pedidos.add(r);
          return http.Response('{"dados":{"status":"NAO_ENVIADA"}}', 201);
        }),
      );
      expect((await service.reiniciarTeste())['sucesso'], true);
      expect(pedidos, hasLength(1));
      expect(pedidos.last.method, 'POST');
      expect(pedidos.last.url.path, '/usuarios/cnh/reiniciar-teste');
      expect(pedidos.last.headers['authorization'], 'Bearer token-teste');
      expect(pedidos.last.body, isEmpty);
    },
  );

  test('backend antigo nao transforma erro em reset', () async {
    final service = VerificacaoCnhService(
      lerCnh: (_) async => {'largura': 1000, 'altura': 800, 'linhas': []},
      cliente: MockClient(
        (_) async => http.Response('{"message":"Recurso indisponivel"}', 404),
      ),
    );
    expect((await service.reiniciarTeste())['sucesso'], false);
  });

  test('le a foto localmente e envia apenas OCR e aceite com token', () async {
    late http.Request recebido;
    final service = VerificacaoCnhService(
      lerCnh: (_) async => {'largura': 1000, 'altura': 800, 'linhas': []},
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
    final resultado = await service.enviar(frente, aceitePrivacidade: true);
    expect(resultado['dados']['status'], 'APROVADA');
    expect(recebido.url.path, '/usuarios/cnh/verificar-mlkit');
    expect(recebido.headers['authorization'], 'Bearer token-teste');
    expect(recebido.headers['content-type'], 'application/json');
    final corpo = jsonDecode(recebido.body) as Map;
    expect(corpo['versaoLeitura'], 'mlkit-v1');
    expect(corpo['aceitePrivacidade'], true);
    expect(corpo.containsKey('nomeCompleto'), false);
    expect(corpo['leitura']['largura'], 1000);
    expect(corpo.containsKey('frente'), false);
    expect(corpo.containsKey('verso'), false);
  });

  test('não envia sem aceite, fotos ou sessão', () async {
    var chamadas = 0;
    final service = VerificacaoCnhService(
      lerCnh: (_) async => {'largura': 1000, 'altura': 800, 'linhas': []},
      cliente: MockClient((_) async {
        chamadas++;
        return http.Response('{}', 500);
      }),
    );
    expect(
      (await service.enviar(frente, aceitePrivacidade: false))['sucesso'],
      isFalse,
    );
    expect(
      (await service.enviar(Uint8List(0), aceitePrivacidade: true))['sucesso'],
      isFalse,
    );
    expect(
      (await service.enviar(
        Uint8List(5 * 1024 * 1024 + 1),
        aceitePrivacidade: true,
      ))['sucesso'],
      isFalse,
    );
    AuthService.tokenUsuarioLogado = null;
    expect(
      (await service.enviar(frente, aceitePrivacidade: true))['mensagem'],
      'Usuário não está logado',
    );
    expect(chamadas, 0);
  });

  test(
    'recusa é um resultado processado e erros de servidor permitem tentar novamente',
    () async {
      final recusada = VerificacaoCnhService(
        lerCnh: (_) async => {'largura': 1000, 'altura': 800, 'linhas': []},
        cliente: MockClient(
          (_) async => http.Response('{"dados":{"status":"RECUSADA"}}', 201),
        ),
      );
      expect(
        (await recusada.enviar(
          frente,
          aceitePrivacidade: true,
        ))['dados']['status'],
        'RECUSADA',
      );
      final falha = VerificacaoCnhService(
        lerCnh: (_) async => {'largura': 1000, 'altura': 800, 'linhas': []},
        cliente: MockClient(
          (_) async => http.Response(
            '{"message":"Serviço temporariamente indisponível"}',
            503,
          ),
        ),
      );
      expect(
        (await falha.enviar(frente, aceitePrivacidade: true))['mensagem'],
        'Serviço temporariamente indisponível',
      );
    },
  );

  test('limita a espera e permite consultar se o servidor concluiu', () async {
    final pendente = Completer<http.Response>();
    final logs = <String>[];
    final service = VerificacaoCnhService(
      lerCnh: (_) async => {'largura': 1000, 'altura': 800, 'linhas': []},
      registrarDiagnostico: logs.add,
      prazo: const Duration(milliseconds: 1),
      cliente: MockClient((_) => pendente.future),
    );
    final resultado = await service.enviar(frente, aceitePrivacidade: true);
    expect(resultado['sucesso'], isFalse);
    expect(resultado['mensagem'], contains('Atualize o status'));
    expect(logs.join('\n'), contains('classe=timeout tipo=TimeoutException'));
    pendente.complete(http.Response('{}', 500));
  });
}
