import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uni_carona/models/carona.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/services/carona_service.dart';

Map<String, dynamic> dadosCarona({int id = 20}) => {
  'idCarona': id,
  'origem': 'Centro',
  'destino': 'Campus',
  'dataInicio': '2026-11-06',
  'horario': '19:00:00',
  'vagas': 2,
  'valor': 5,
  'usuario': {'idUsuario': 2, 'nome': 'Motorista'},
};

class ClienteObservado extends MockClient {
  bool fechado = false;
  ClienteObservado(super.handler);

  @override
  void close() {
    fechado = true;
    super.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    AuthService.tokenUsuarioLogado = 'token-teste';
  });
  tearDown(() {
    AuthService.tokenUsuarioLogado = null;
  });

  test(
    'consulta carona especifica com autenticacao e dados completos',
    () async {
      final resultado = await http.runWithClient(
        () => CaronaService.buscarDetalhesCarona(20),
        () => MockClient((request) async {
          expect(request.url.path.endsWith('/caronas/20'), isTrue);
          expect(request.method, 'GET');
          expect(request.headers['Authorization'], 'Bearer token-teste');
          return http.Response(
            jsonEncode({
              'sucesso': true,
              'dados': {
                'idCarona': 20,
                'origem': 'Centro',
                'destino': 'Campus',
                'dataInicio': '2026-10-08',
                'horario': '19:00:00',
                'vagas': 2,
                'valor': 8,
                'status': 'FINALIZADA',
                'observacoes': 'Portaria principal',
                'usuario': {
                  'idUsuario': 2,
                  'nome': 'Maria',
                  'veiculo': {
                    'modelo': 'Onix',
                    'cor': 'Branco',
                    'placa': '***1D23',
                  },
                },
              },
            }),
            200,
          );
        }),
      );
      expect(resultado['sucesso'], isTrue);
      final carona = resultado['dados'] as Carona;
      expect(carona.id, 20);
      expect(carona.status, 'FINALIZADA');
      expect(carona.origem, 'Centro');
      expect(carona.veiculoModelo, 'Onix');
      expect(carona.veiculoPlaca, '***1D23');
      expect(carona.observacoes, 'Portaria principal');
    },
  );

  test('nao consulta carona sem sessao', () async {
    AuthService.tokenUsuarioLogado = null;
    final resultado = await CaronaService.buscarDetalhesCarona(20);
    expect(resultado['sucesso'], isFalse);
    expect(resultado['mensagem'], 'Usuário não está logado');
  });

  test('preserva mensagem de carona inexistente ou nao autorizada', () async {
    final resultado = await http.runWithClient(
      () => CaronaService.buscarDetalhesCarona(20),
      () => MockClient(
        (_) async => http.Response(
          jsonEncode({'message': 'Carona não encontrada'}),
          404,
        ),
      ),
    );
    expect(resultado['sucesso'], isFalse);
    expect(resultado['mensagem'], 'Carona não encontrada');
  });

  test('resposta incompleta nao abre detalhes invalidos', () async {
    final resultado = await http.runWithClient(
      () => CaronaService.buscarDetalhesCarona(20),
      () => MockClient((_) async => http.Response('{"dados":{}}', 200)),
    );
    expect(resultado['sucesso'], isFalse);
  });

  for (final corpo in [
    '{}',
    '[]',
    '<html>indisponivel</html>',
    jsonEncode({'sucesso': false, 'dados': dadosCarona()}),
    jsonEncode({'sucesso': true, 'dados': dadosCarona(id: 99)}),
  ]) {
    test('rejeita resposta invalida ou de outra carona: $corpo', () async {
      final resultado = await http.runWithClient(
        () => CaronaService.buscarDetalhesCarona(20),
        () => MockClient((_) async => http.Response(corpo, 200)),
      );
      expect(resultado['sucesso'], isFalse);
      expect(AuthService.estaLogado, isTrue);
    });
  }

  test('id invalido nao envia HTTP', () async {
    var consultas = 0;
    await http.runWithClient(
      () async {
        expect(
          (await CaronaService.buscarDetalhesCarona(0))['sucesso'],
          isFalse,
        );
        expect(
          (await CaronaService.buscarDetalhesCarona(-1))['sucesso'],
          isFalse,
        );
      },
      () => MockClient((_) async {
        consultas++;
        throw StateError('HTTP inesperado');
      }),
    );
    expect(consultas, 0);
  });

  for (final status in [401, 429, 503]) {
    test('trata HTTP $status mesmo com resposta HTML', () async {
      final resultado = await http.runWithClient(
        () => CaronaService.buscarDetalhesCarona(20),
        () =>
            MockClient((_) async => http.Response('<html>erro</html>', status)),
      );
      expect(resultado['sucesso'], isFalse);
      expect(AuthService.estaLogado, status != 401);
      expect(
        resultado['mensagem'],
        contains(
          status == 401
              ? 'sessão expirou'
              : status == 429
              ? 'Aguarde'
              : 'indisponível',
        ),
      );
    });
  }

  testWidgets('prazo encerra conexao, libera retry e nao encerra sessao', (
    tester,
  ) async {
    final pendente = Completer<http.Response>();
    final cliente = ClienteObservado((_) => pendente.future);
    final consulta = http.runWithClient(
      () => CaronaService.buscarDetalhesCarona(
        20,
        prazo: const Duration(seconds: 1),
      ),
      () => cliente,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    final resultado = await consulta;
    expect(resultado['sucesso'], isFalse);
    expect(resultado['mensagem'], contains('demorou'));
    expect(cliente.fechado, isTrue);
    expect(AuthService.estaLogado, isTrue);
    final nova = await http.runWithClient(
      () => CaronaService.buscarDetalhesCarona(20),
      () => MockClient(
        (_) async => http.Response(jsonEncode({'dados': dadosCarona()}), 200),
      ),
    );
    expect(nova['sucesso'], isTrue);
    pendente.complete(
      http.Response(jsonEncode({'dados': dadosCarona(id: 99)}), 200),
    );
    await tester.pump();
    expect((nova['dados'] as Carona).id, 20);
  });

  for (final falha in [false, true]) {
    test('fecha o cliente apos resposta falha=$falha', () async {
      final cliente = ClienteObservado((_) async {
        if (falha) throw http.ClientException('offline');
        return http.Response(jsonEncode({'dados': dadosCarona()}), 200);
      });
      final resultado = await http.runWithClient(
        () => CaronaService.buscarDetalhesCarona(20),
        () => cliente,
      );
      expect(resultado['sucesso'], !falha);
      expect(cliente.fechado, isTrue);
    });
  }
}
