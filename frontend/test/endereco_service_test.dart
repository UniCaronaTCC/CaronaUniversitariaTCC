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
