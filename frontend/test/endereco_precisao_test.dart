import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uni_carona/mapa/models/localizacao_selecionada.dart';
import 'package:uni_carona/mapa/services/endereco_service.dart';

Map<String, dynamic> localJson({
  String nome = 'Rua Brasil',
  String rua = 'Rua Brasil',
  String? numero = '123',
  String? tipo = 'house',
  String? osmKey,
  String? osmValue,
  String cidade = 'Aracatuba',
  double latitude = -21.2,
}) => {
  'geometry': {
    'coordinates': [-50.4, latitude],
  },
  'properties': {
    'countrycode': 'BR',
    'name': nome,
    'street': rua,
    'housenumber': numero,
    'city': cidade,
    'state': 'Sao Paulo',
    'type': ?tipo,
    'osm_key': ?osmKey,
    'osm_value': ?osmValue,
  },
};
http.Response resposta(List<Map<String, dynamic>> locais) =>
    http.Response.bytes(utf8.encode(jsonEncode({'features': locais})), 200);

void main() {
  test(
    'cidade sem campo city preserva nome e precede estabelecimentos ao buscar municipio',
    () async {
      final cidade = localJson(
        nome: 'Curitiba',
        rua: '',
        numero: null,
        tipo: 'city',
        osmKey: 'place',
        osmValue: 'municipality',
      );
      (cidade['properties'] as Map).remove('city');
      final cliente = MockClient(
        (_) async =>
            resposta([cidade, localJson(nome: 'Mercado', cidade: 'Curitiba')]),
      );
      addTearDown(cliente.close);
      final locais = await EnderecoService(
        cliente: cliente,
      ).buscarLocalizacoesPorEndereco('Curitiba');
      expect(locais.first.nome, 'Curitiba');
      expect(locais.first.cidade, 'Curitiba');
      expect(locais.first.precisao, PrecisaoLocalizacao.regiao);
      expect(locais.first.exigeAjusteNoMapa, true);
    },
  );
  test('nao confirma numero igual recebido em outra rua', () async {
    final cliente = MockClient(
      (_) async => resposta([localJson(rua: 'Rua Outra', numero: '123')]),
    );
    addTearDown(cliente.close);
    final locais = await EnderecoService(
      cliente: cliente,
    ).buscarLocalizacoesPorEndereco('Rua Brasil, 123');
    expect(locais.single.numero, '123');
    expect(locais.single.numeroNaoConfirmado, true);
    expect(locais.single.exigeAjusteNoMapa, true);
  });
  test(
    'identificador numerico confirmado no nome da rua nao vira numero de casa',
    () async {
      var chamadas = 0;
      final cliente = MockClient((_) async {
        chamadas++;
        return resposta([
          localJson(
            nome: 'Rua Projetada 2',
            rua: 'Rua Projetada 2',
            numero: null,
            tipo: 'street',
          ),
        ]);
      });
      addTearDown(cliente.close);
      final locais = await EnderecoService(
        cliente: cliente,
      ).buscarLocalizacoesPorEndereco('Rua Projetada 2');
      expect(chamadas, 1);
      expect(locais.single.rua, 'Rua Projetada 2');
      expect(locais.single.numeroBuscado, isNull);
      expect(locais.single.exigeAjusteNoMapa, true);
    },
  );
  for (final caso in [
    (
      localJson(
        tipo: null,
        osmKey: 'place',
        osmValue: 'city',
        numero: null,
        rua: '',
      ),
      PrecisaoLocalizacao.regiao,
    ),
    (
      localJson(tipo: 'district', numero: null, rua: ''),
      PrecisaoLocalizacao.regiao,
    ),
    (
      localJson(
        tipo: null,
        osmKey: 'amenity',
        osmValue: 'university',
        numero: null,
        rua: '',
      ),
      PrecisaoLocalizacao.ponto,
    ),
    (
      localJson(
        tipo: null,
        osmKey: 'highway',
        osmValue: 'residential',
        numero: null,
        rua: '',
      ),
      PrecisaoLocalizacao.rua,
    ),
    (
      localJson(tipo: null, numero: null, rua: ''),
      PrecisaoLocalizacao.desconhecida,
    ),
    (localJson(tipo: null), PrecisaoLocalizacao.ponto),
  ]) {
    test('classifica ${caso.$2} mesmo sem properties.type', () async {
      final cliente = MockClient((_) async => resposta([caso.$1]));
      addTearDown(cliente.close);
      final locais = await EnderecoService(
        cliente: cliente,
      ).buscarLocalizacoesPorEndereco('universidade');
      expect(locais.single.precisao, caso.$2);
      expect(
        locais.single.exigeAjusteNoMapa,
        caso.$2 != PrecisaoLocalizacao.ponto,
      );
    });
  }
  for (final consulta in [
    'Rua Brasil, 123',
    'Rua Brasil 123',
    'R. Brasil, 123',
  ]) {
    test('prioriza numero exato antes da proximidade: $consulta', () async {
      var chamadas = 0;
      final cliente = MockClient((_) async {
        chamadas++;
        return resposta([
          localJson(numero: '321'),
          localJson(numero: null, tipo: 'street', latitude: -21.21),
          localJson(latitude: -21.3),
        ]);
      });
      addTearDown(cliente.close);
      final locais = await EnderecoService(cliente: cliente)
          .buscarLocalizacoesPorEndereco(
            consulta,
            latitudeReferencia: -21.2,
            longitudeReferencia: -50.4,
          );
      expect(locais.first.numero, '123');
      expect(locais.first.exigeAjusteNoMapa, false);
      expect(locais[1].precisao, PrecisaoLocalizacao.rua);
      expect(locais[1].exigeAjusteNoMapa, true);
      expect(locais.last.numero, '321');
      expect(locais.last.numeroNaoConfirmado, true);
      expect(chamadas, 1);
    });
  }
  test(
    'numero ausente busca rua e cidade sem inventar numero nem exceder duas chamadas',
    () async {
      final chamadas = <String>[];
      final cliente = MockClient((request) async {
        chamadas.add(request.url.queryParameters['q']!);
        return resposta(
          chamadas.length == 1 ? [] : [localJson(numero: null, tipo: 'street')],
        );
      });
      addTearDown(cliente.close);
      final locais = await EnderecoService(
        cliente: cliente,
      ).buscarLocalizacoesPorEndereco('Rua Brasil, 123, Aracatuba');
      expect(chamadas, ['Rua Brasil, 123, Aracatuba', 'Rua Brasil, Aracatuba']);
      expect(locais.single.numero, isNull);
      expect(locais.single.numeroBuscado, '123');
      expect(locais.single.endereco, isNot(contains('123')));
      expect(locais.single.exigeAjusteNoMapa, true);
    },
  );
  test(
    'tenta numero ausente mesmo com muitas sugestoes e preserva resultados na falha',
    () async {
      var chamadas = 0;
      final cliente = MockClient((_) async {
        if (++chamadas == 2) throw TimeoutException('complementar');
        return resposta([
          for (var i = 0; i < 6; i++)
            localJson(nome: 'Local $i', numero: '${200 + i}'),
        ]);
      });
      addTearDown(cliente.close);
      final locais = await EnderecoService(
        cliente: cliente,
      ).buscarLocalizacoesPorEndereco('Rua Brasil, 123');
      expect(chamadas, 2);
      expect(locais, hasLength(5));
      expect(locais.every((l) => l.numeroNaoConfirmado), true);
    },
  );
  test('rua sem numero nao e compactada em chamada inutil', () async {
    var chamadas = 0;
    final cliente = MockClient((_) async {
      chamadas++;
      return resposta([]);
    });
    addTearDown(cliente.close);
    expect(
      await EnderecoService(
        cliente: cliente,
      ).buscarLocalizacoesPorEndereco('Rua Brasil'),
      isEmpty,
    );
    expect(chamadas, 1);
  });
  test('Sao no logradouro nao e interpretado como cidade solicitada', () async {
    final cliente = MockClient(
      (_) async => resposta([
        localJson(
          nome: 'Rua Sao Joao',
          rua: 'Rua Sao Joao',
          numero: null,
          tipo: 'street',
          cidade: 'Sao Paulo',
        ),
        localJson(
          nome: 'Rua Sao Joao',
          rua: 'Rua Sao Joao',
          numero: null,
          tipo: 'street',
        ),
      ]),
    );
    addTearDown(cliente.close);
    final locais = await EnderecoService(cliente: cliente)
        .buscarLocalizacoesPorEndereco(
          'Rua Sao Joao',
          cidadeReferencia: 'Aracatuba',
        );
    expect(locais.first.cidade, 'Aracatuba');
  });
  test('cidade inteira escrita prevalece sobre GPS e nome parecido', () async {
    final cliente = MockClient(
      (_) async => resposta([
        localJson(nome: 'Universidade Curitiba'),
        localJson(nome: 'Universidade', cidade: 'Curitiba', latitude: -25.4),
      ]),
    );
    addTearDown(cliente.close);
    final locais = await EnderecoService(cliente: cliente)
        .buscarLocalizacoesPorEndereco(
          'Universidade Curitiba',
          cidadeReferencia: 'Aracatuba',
          latitudeReferencia: -21.2,
          longitudeReferencia: -50.4,
        );
    expect(locais.first.cidade, 'Curitiba');
  });
}
