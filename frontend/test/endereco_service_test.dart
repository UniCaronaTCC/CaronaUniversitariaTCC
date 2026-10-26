import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uni_carona/mapa/services/endereco_service.dart';

Map<String, dynamic> feature({
  String nome = 'UniSALESIANO',
  double latitude = -21.235275,
  double longitude = -50.4060626,
  String? numero = '3821',
  String cidade = 'Aracatuba',
  String rua = 'Rodovia Senador Teotonio Vilela',
  String estado = 'Sao Paulo',
}) => {
  'geometry': {
    'coordinates': [longitude, latitude],
  },
  'properties': {
    'name': nome,
    'countrycode': 'BR',
    'city': cidade,
    'state': estado,
    'country': 'Brasil',
    'street': rua,
    'housenumber': numero,
    'type': 'house',
  },
};

Future<List<dynamic>> buscar(List<Map<String, dynamic>> features) async {
  final client = MockClient(
    (request) async => http.Response(jsonEncode({'features': features}), 200),
  );
  try {
    return await EnderecoService(
      cliente: client,
    ).buscarLocalizacoesPorEndereco('unisalesiano');
  } finally {
    client.close();
  }
}

void main() {
  test('pede Brasil sem alterar texto nem restringir cidade', () async {
    final cliente = MockClient((request) async {
      expect(request.url.queryParameters, {
        'q': 'Rua Brasil Curitiba',
        'limit': '15',
        'countrycode': 'BR',
        'lat': '-21.2',
        'lon': '-50.4',
      });
      return http.Response(
        jsonEncode({
          'features': [feature(), feature(nome: 'B'), feature(nome: 'C')],
        }),
        200,
      );
    });
    addTearDown(cliente.close);
    await EnderecoService(cliente: cliente).buscarLocalizacoesPorEndereco(
      'Rua Brasil Curitiba',
      latitudeReferencia: -21.2,
      longitudeReferencia: -50.4,
      cidadeReferencia: 'Aracatuba',
      estadoReferencia: 'SP',
    );
  });

  for (final coordenadas in [
    (double.nan, -50.4),
    (-91.0, -50.4),
    (-21.2, 181.0),
    (-21.2, null),
    (null, null),
  ]) {
    test('ignora referencia incompleta ou invalida $coordenadas', () async {
      final cliente = MockClient((request) async {
        expect(request.url.queryParameters.containsKey('lat'), false);
        expect(request.url.queryParameters.containsKey('lon'), false);
        return http.Response('{"features":[]}', 200);
      });
      addTearDown(cliente.close);
      expect(
        await EnderecoService(cliente: cliente).buscarLocalizacoesPorEndereco(
          'rua',
          latitudeReferencia: coordenadas.$1,
          longitudeReferencia: coordenadas.$2,
        ),
        isEmpty,
      );
    });
  }

  for (final status in [400, 403, 429, 500, 503]) {
    test('HTTP $status e falha identificada, nao lista vazia', () async {
      var chamadas = 0;
      final cliente = MockClient((_) async {
        chamadas++;
        return http.Response('falha', status);
      });
      addTearDown(cliente.close);
      await expectLater(
        EnderecoService(
          cliente: cliente,
        ).buscarLocalizacoesPorEndereco('Rua Brasil'),
        throwsA(
          isA<FalhaBuscaEndereco>().having(
            (e) => e.tipo,
            'tipo',
            status == 429
                ? TipoFalhaEndereco.limite
                : TipoFalhaEndereco.indisponivel,
          ),
        ),
      );
      expect(chamadas, 1);
    });
  }

  for (final corpo in [
    '<html>erro</html>',
    'null',
    '[]',
    '{}',
    '{"features":{}}',
  ]) {
    test('resposta invalida $corpo nao parece resultado vazio', () async {
      final cliente = MockClient((_) async => http.Response(corpo, 200));
      addTearDown(cliente.close);
      await expectLater(
        EnderecoService(
          cliente: cliente,
        ).buscarLocalizacoesPorEndereco('Rua Brasil'),
        throwsA(
          isA<FalhaBuscaEndereco>().having(
            (e) => e.tipo,
            'tipo',
            TipoFalhaEndereco.respostaInvalida,
          ),
        ),
      );
    });
  }

  test(
    'conexao interrompida nao expoe mensagem tecnica nem termo pesquisado',
    () async {
      final cliente = MockClient(
        (_) async => throw http.ClientException('segredo rua abc'),
      );
      addTearDown(cliente.close);
      await expectLater(
        EnderecoService(
          cliente: cliente,
        ).buscarLocalizacoesPorEndereco('Rua Brasil'),
        throwsA(
          isA<FalhaBuscaEndereco>()
              .having((e) => e.tipo, 'tipo', TipoFalhaEndereco.conexao)
              .having(
                (e) => e.mensagem.contains('segredo'),
                'nao expoe detalhe',
                false,
              ),
        ),
      );
    },
  );

  test(
    'timeout real permite nova consulta com o mesmo cliente injetado',
    () async {
      var chamadas = 0;
      final pendente = Completer<http.Response>();
      final cliente = MockClient(
        (_) async => ++chamadas == 1
            ? await pendente.future
            : http.Response('{"features":[]}', 200),
      );
      addTearDown(cliente.close);
      final service = EnderecoService(
        cliente: cliente,
        prazo: const Duration(milliseconds: 15),
      );
      await expectLater(
        service.buscarLocalizacoesPorEndereco('rua'),
        throwsA(
          isA<FalhaBuscaEndereco>().having(
            (e) => e.tipo,
            'tipo',
            TipoFalhaEndereco.tempoEsgotado,
          ),
        ),
      );
      expect(await service.buscarLocalizacoesPorEndereco('rua'), isEmpty);
      pendente.complete(http.Response('{"features":[]}', 200));
    },
  );

  for (final erro in [
    TimeoutException('tarde'),
    http.ClientException('rede'),
    const FormatException('json'),
  ]) {
    test('falha complementar $erro preserva sugestao valida', () async {
      var chamadas = 0;
      final cliente = MockClient((_) async {
        if (++chamadas > 1) throw erro;
        return http.Response(
          jsonEncode({
            'features': [feature()],
          }),
          200,
        );
      });
      addTearDown(cliente.close);
      final encontrados = await EnderecoService(
        cliente: cliente,
      ).buscarLocalizacoesPorEndereco('uni salesiano');
      expect(encontrados.single.nome, 'UniSALESIANO');
      expect(chamadas, 2);
    });
  }

  test(
    'primeira vazia e complementar indisponivel nao dizem que nada existe',
    () async {
      var chamadas = 0;
      final cliente = MockClient(
        (_) async => ++chamadas == 1
            ? http.Response('{"features":[]}', 200)
            : http.Response('', 503),
      );
      addTearDown(cliente.close);
      await expectLater(
        EnderecoService(
          cliente: cliente,
        ).buscarLocalizacoesPorEndereco('Rua Brasil'),
        throwsA(isA<FalhaBuscaEndereco>()),
      );
      expect(chamadas, 2);
    },
  );

  test('duas consultas validas vazias continuam sendo ausencia real', () async {
    final cliente = MockClient(
      (_) async => http.Response('{"features":[]}', 200),
    );
    addTearDown(cliente.close);
    expect(
      await EnderecoService(
        cliente: cliente,
      ).buscarLocalizacoesPorEndereco('Rua Brasil'),
      isEmpty,
    );
  });

  test('menos de tres letras nao consulta o provedor', () async {
    final cliente = MockClient(
      (_) async => throw StateError('nao deveria consultar'),
    );
    addTearDown(cliente.close);
    expect(
      await EnderecoService(
        cliente: cliente,
      ).buscarLocalizacoesPorEndereco('ab'),
      isEmpty,
    );
  });

  test(
    'cidade de referencia prioriza mas nao exclui resultados de outra cidade',
    () async {
      final cliente = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'features': [
              feature(nome: 'Mercado', cidade: 'Outra cidade', latitude: -23),
              feature(nome: 'Mercado', cidade: 'Aracatuba'),
            ],
          }),
          200,
        ),
      );
      addTearDown(cliente.close);
      final locais = await EnderecoService(
        cliente: cliente,
      ).buscarLocalizacoesPorEndereco('mercado', cidadeReferencia: 'Aracatuba');
      expect(locais, hasLength(2));
      expect(locais.first.cidade, 'Aracatuba');
    },
  );
  test('agrupa ponto e area reais do mesmo campus e prefere numero', () async {
    final resultados = await buscar([
      feature(
        nome: 'Unisalesiano',
        numero: null,
        latitude: -21.2358733,
        longitude: -50.40848,
      ),
      feature(),
    ]);
    expect(resultados, hasLength(1));
    expect(resultados.single.nome, 'UniSALESIANO');
    expect(resultados.single.numero, '3821');
    expect(resultados.single.ponto.latitude, -21.235275);
  });

  test('mantem unidades distantes da mesma instituicao', () async {
    expect(await buscar([feature(), feature(latitude: -21.25)]), hasLength(2));
  });

  test('nao mistura estabelecimentos vizinhos de nomes diferentes', () async {
    expect(
      await buscar([feature(), feature(nome: 'Outra faculdade')]),
      hasLength(2),
    );
  });

  for (final outro in [
    feature(numero: '4000'),
    feature(cidade: 'Outra cidade'),
    feature(rua: 'Outra rua'),
    feature(estado: 'Outro estado'),
  ]) {
    test(
      'preserva locais com endereco incompativel: ${outro['properties']}',
      () async {
        expect(await buscar([feature(), outro]), hasLength(2));
      },
    );
  }

  test(
    'remove duplicatas da lista principal mesmo sem busca alternativa',
    () async {
      expect(await buscar([feature(), feature(), feature()]), hasLength(1));
    },
  );

  test('descarta coordenadas invalidas e resultados malformados', () async {
    expect(
      await buscar([
        feature(latitude: 91),
        feature(longitude: 200),
        {},
        feature(),
      ]),
      hasLength(1),
    );
  });

  test('busca alternativa tambem compartilha agrupamento', () async {
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode({
          'features': request.url.queryParameters['q'] == 'uni salesiano'
              ? [feature(nome: 'Uni Salesiano', numero: null)]
              : [feature()],
        }),
        200,
      ),
    );
    final results = await EnderecoService(
      cliente: client,
    ).buscarLocalizacoesPorEndereco('uni salesiano');
    expect(results, hasLength(1));
    expect(results.single.numero, '3821');
    client.close();
  });
}
