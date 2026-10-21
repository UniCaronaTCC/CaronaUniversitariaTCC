import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uni_carona/models/capacidade_carona.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/services/carona_service.dart';

Map<String, dynamic> capacidadeJson() => {
  'capacidadePassageiros': 4,
  'passageirosAceitos': 2,
  'vagasDisponiveis': 2,
};

Future<Map<String, dynamic>> salvar({
  int? idCarona,
  int? idRecorrencia,
  int? total,
  int? anterior,
}) => CaronaService.salvarCarona(
  idCarona: idCarona,
  idRecorrencia: idRecorrencia,
  origem: 'Rua A, 10',
  origemLatitude: -21,
  origemLongitude: -50,
  destino: 'Campus',
  destinoLatitude: -21.1,
  destinoLongitude: -50.1,
  pontosEmbarque: [],
  dataInicio: '2099-12-01',
  horario: '18:00:00',
  vagas: 3,
  capacidadePassageiros: total,
  capacidadeAnterior: anterior,
  valor: 5,
  recorrente: idRecorrencia != null,
  diasSemana: idRecorrencia == null ? null : ['SEG'],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    AuthService.tokenUsuarioLogado = 'token-teste';
  });
  tearDown(() => AuthService.tokenUsuarioLogado = null);

  test('modelo distingue capacidade, aceitos e livres inclusive lotada', () {
    final c = CapacidadeCarona.fromJson(capacidadeJson());
    expect([c.total, c.aceitos, c.livres], [4, 2, 2]);
    final lotada = CapacidadeCarona.fromJson({
      'capacidadePassageiros': 4,
      'passageirosAceitos': 4,
      'vagasDisponiveis': 0,
    });
    expect(lotada.livres, 0);
  });

  for (final alteracao in <Map<String, dynamic>>[
    {},
    {'capacidadePassageiros': 0},
    {'capacidadePassageiros': 5},
    {'capacidadePassageiros': '4'},
    {'passageirosAceitos': -1},
    {'passageirosAceitos': 5},
    {'vagasDisponiveis': -1},
    {'vagasDisponiveis': 1},
    {'passageirosAceitos': null},
  ]) {
    test('modelo recusa resposta inconsistente $alteracao', () {
      expect(
        () => CapacidadeCarona.fromJson(
          alteracao.isEmpty ? {} : {...capacidadeJson(), ...alteracao},
        ),
        throwsFormatException,
      );
    });
  }

  test(
    'consulta autenticada usa endpoint especifico e retorna modelo',
    () async {
      final r = await http.runWithClient(
        () => CaronaService.buscarCapacidade(10),
        () => MockClient((req) async {
          expect(req.method, 'GET');
          expect(req.url.path, '/caronas/10/capacidade');
          expect(req.headers['Authorization'], 'Bearer token-teste');
          return http.Response(
            jsonEncode({'sucesso': true, 'dados': capacidadeJson()}),
            200,
          );
        }),
      );
      expect(r['sucesso'], isTrue);
      expect((r['dados'] as CapacidadeCarona).total, 4);
    },
  );

  for (final status in [404, 409, 500]) {
    test('consulta trata HTTP $status sem liberar edicao', () async {
      final r = await http.runWithClient(
        () => CaronaService.buscarCapacidade(10),
        () => MockClient(
          (_) async => http.Response(
            jsonEncode({'message': 'Carona indisponivel'}),
            status,
          ),
        ),
      );
      expect(r['sucesso'], isFalse);
      expect(r['mensagem'], isNotEmpty);
    });
  }

  for (final body in [
    '<html>erro</html>',
    '{}',
    '{"sucesso":true,"dados":{}}',
  ]) {
    test('consulta recusa resposta incompleta $body', () async {
      final r = await http.runWithClient(
        () => CaronaService.buscarCapacidade(10),
        () => MockClient((_) async => http.Response(body, 200)),
      );
      expect(r['sucesso'], isFalse);
    });
  }

  test('consulta sem sessao nao faz requisicao', () async {
    AuthService.tokenUsuarioLogado = null;
    final r = await CaronaService.buscarCapacidade(10);
    expect(r['sucesso'], isFalse);
  });

  test('consulta trata falha de rede', () async {
    final r = await http.runWithClient(
      () => CaronaService.buscarCapacidade(10),
      () => MockClient((_) async => throw http.ClientException('offline')),
    );
    expect(r['sucesso'], isFalse);
  });

  test('consulta tem prazo limitado', () async {
    final pendente = Completer<http.Response>();
    final r = await http.runWithClient(
      () => CaronaService.buscarCapacidade(
        10,
        prazo: const Duration(milliseconds: 10),
      ),
      () => MockClient((_) => pendente.future),
    );
    expect(r['sucesso'], isFalse);
    pendente.complete(http.Response('{}', 200));
  });

  test(
    'edicao envia capacidade total e referencia, nunca vagas livres',
    () async {
      final r = await http.runWithClient(
        () => salvar(idCarona: 10, total: 3, anterior: 4),
        () => MockClient((req) async {
          expect(req.method, 'PATCH');
          expect(req.url.path, '/caronas/10');
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          expect(body['capacidadePassageiros'], 3);
          expect(body['capacidadeAnterior'], 4);
          expect(body.containsKey('vagas'), isFalse);
          return http.Response('{"sucesso":true}', 200);
        }),
      );
      expect(r['sucesso'], isTrue);
    },
  );

  test('edicao sem consulta previa nao envia requisicao', () async {
    var chamadas = 0;
    final r = await http.runWithClient(
      () => salvar(idCarona: 10),
      () => MockClient((_) async {
        chamadas++;
        return http.Response('{}', 200);
      }),
    );
    expect(r['sucesso'], isFalse);
    expect(chamadas, 0);
  });

  test('preserva mensagem de conflito de capacidade', () async {
    final r = await http.runWithClient(
      () => salvar(idCarona: 10, total: 2, anterior: 4),
      () => MockClient(
        (_) async => http.Response('{"message":"Reabra a carona"}', 409),
      ),
    );
    expect(r['sucesso'], isFalse);
    expect(r['mensagem'], 'Reabra a carona');
  });

  for (final programacao in [false, true]) {
    test(
      'preserva contrato de ${programacao ? 'programacao' : 'criacao'}',
      () async {
        await http.runWithClient(
          () => salvar(idRecorrencia: programacao ? 20 : null),
          () => MockClient((req) async {
            expect(req.method, programacao ? 'PATCH' : 'POST');
            expect(req.url.path, programacao ? '/recorrencias/20' : '/caronas');
            final body = jsonDecode(req.body) as Map<String, dynamic>;
            expect(body['vagas'], 3);
            expect(body.containsKey('capacidadePassageiros'), isFalse);
            return http.Response('{}', 200);
          }),
        );
      },
    );
  }
}
