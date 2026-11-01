import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:uni_carona/mapa/models/localizacao_selecionada.dart';
import 'package:uni_carona/models/campus_destino.dart';

Map<String, dynamic> campusJson() => {
  'idCampus': 10,
  'idInstituicao': 1,
  'nome': 'Universidade Estadual Paulista',
  'sigla': 'UNESP',
  'campus': 'Araçatuba - Odontologia',
  'municipio': 'Araçatuba',
  'uf': 'SP',
  'latitude': -21.2,
  'longitude': -50.4,
};

void main() {
  test('identificacao da cidade preserva coordenadas sem mudar comparacao', () {
    final cidade = CidadeCampus.deLocalizacao(
      const LocalizacaoSelecionada(
        ponto: LatLng(-21.2, -50.4),
        endereco: 'Rua',
        cidade: 'Araçatuba',
        estado: 'São Paulo',
      ),
    );
    expect(cidade!.pontoReferencia, const LatLng(-21.2, -50.4));
    expect(cidade.mesmaCidade(const CidadeCampus('Aracatuba', 'SP')), isTrue);
    expect(const CidadeCampus('Outra cidade', 'SP').pontoReferencia, isNull);
  });
  test(
    'converte identificadores e ponto, com endereço de cidade explicitamente identificado',
    () {
      final campus = CampusDestino.fromJson(campusJson());
      expect(campus.idCampus, 10);
      expect(campus.localizacao!.ponto, const LatLng(-21.2, -50.4));
      expect(campus.localizacao!.cidade, 'Araçatuba');
      expect(campus.titulo, 'UNESP · Araçatuba - Odontologia');
    },
  );

  for (final termo in [
    '',
    'u',
    'un',
    'UNESP',
    'odontologia',
    'aracatuba',
    'estadual odontologia',
  ]) {
    test('filtra desde zero ou uma letra: $termo', () {
      expect(CampusDestino.fromJson(campusJson()).corresponde(termo), isTrue);
    });
  }
  test('não confunde campi da mesma instituição', () {
    expect(
      CampusDestino.fromJson(campusJson()).corresponde('veterinaria'),
      isFalse,
    );
  });
  test('normaliza sigla e nome de todos os estados, com e sem acento', () {
    expect(CidadeCampus.estados, hasLength(27));
    for (final estado in CidadeCampus.estados.entries) {
      expect(CidadeCampus.normalizarUf(estado.key.toLowerCase()), estado.key);
      expect(
        CidadeCampus.normalizarUf(normalizarDestino(estado.value)),
        estado.key,
      );
    }
    expect(CidadeCampus.normalizarUf('Estado desconhecido'), isNull);
  });
  test('sem coordenadas exige confirmação em vez de fabricar localização', () {
    final campus = CampusDestino.fromJson({
      ...campusJson(),
      'latitude': null,
      'longitude': null,
    });
    expect(campus.localizacao, isNull);
  });
  for (final alteracao in [
    {'idCampus': 0},
    {'idInstituicao': '1'},
    {'nome': ''},
    {'campus': null},
    {'uf': 'XX'},
    {'sigla': 2},
    {'latitude': 91},
    {'longitude': -181},
    {'latitude': null},
    {'latitude': double.nan},
    {'latitude': '-21.2'},
  ]) {
    test('rejeita dados inválidos $alteracao', () {
      expect(
        () => CampusDestino.fromJson({...campusJson(), ...alteracao}),
        throwsFormatException,
      );
    });
  }
  test(
    'só elimina repetição de endereço se nome e proximidade forem compatíveis',
    () {
      final campus = CampusDestino.fromJson(campusJson());
      LocalizacaoSelecionada local(String nome, double latitude) =>
          LocalizacaoSelecionada(
            ponto: LatLng(latitude, -50.4),
            nome: nome,
            endereco: 'Rua',
          );
      expect(campus.mesmoLocal(local('Unesp', -21.2)), isTrue);
      expect(campus.mesmoLocal(local('Outra faculdade', -21.2)), isFalse);
      expect(campus.mesmoLocal(local('Unesp', -22.2)), isFalse);
    },
  );
  test('nome completo é usado quando a sigla está ausente', () {
    expect(
      CampusDestino.fromJson({...campusJson(), 'sigla': null}).titulo,
      startsWith('Universidade Estadual Paulista'),
    );
  });

  test(
    'metadados mudam a apresentação sem substituir o nome interno ou ponto',
    () {
      final campus = CampusDestino.fromJson({
        ...campusJson(),
        'rotuloUnidade': '  Odontologia - José Bonifácio  ',
        'enderecoCompleto': '  Rua José Bonifácio, 1193 - Vila Mendonça  ',
      });
      expect(campus.campus, 'Araçatuba - Odontologia');
      expect(campus.titulo, 'UNESP · Odontologia - José Bonifácio');
      expect(
        campus.descricaoEndereco,
        'Rua José Bonifácio, 1193 - Vila Mendonça · Araçatuba, SP',
      );
      expect(campus.localizacao!.ponto, const LatLng(-21.2, -50.4));
      expect(campus.localizacao!.endereco, contains('1193'));
      expect(campus.localizacao!.exigeAjusteNoMapa, isFalse);
      expect(
        LocalizacaoSelecionada.fromJson(campus.localizacao!.toJson()).toJson(),
        campus.localizacao!.toJson(),
      );
    },
  );

  for (final metadados in [
    <String, dynamic>{},
    {'rotuloUnidade': null, 'enderecoCompleto': null},
    {'rotuloUnidade': '', 'enderecoCompleto': '   '},
  ]) {
    test(
      'mantém compatibilidade com metadados ausentes ou vazios: $metadados',
      () {
        final campus = CampusDestino.fromJson({...campusJson(), ...metadados});
        expect(campus.rotuloUnidade, isNull);
        expect(campus.enderecoCompleto, isNull);
        expect(campus.titulo, 'UNESP · Araçatuba - Odontologia');
        expect(campus.descricaoEndereco, 'Araçatuba, SP');
        expect(campus.localizacao!.endereco, 'Araçatuba, SP, Brasil');
      },
    );
  }

  for (final termo in [
    'jose BONIFACIO',
    '1193',
    'vila mendonca',
    'unesp 1193',
  ]) {
    test('filtra também por unidade, rua, bairro e número: $termo', () {
      final campus = CampusDestino.fromJson({
        ...campusJson(),
        'rotuloUnidade': 'Odontologia - José Bonifácio',
        'enderecoCompleto': 'Rua José Bonifácio, 1193 - Vila Mendonça',
      });
      expect(campus.corresponde(termo), isTrue);
      expect(campus.corresponde('1194'), isFalse);
    });
  }

  test('endereço sem coordenadas não fabrica localização', () {
    final campus = CampusDestino.fromJson({
      ...campusJson(),
      'latitude': null,
      'longitude': null,
      'enderecoCompleto': 'Rua José Bonifácio, 1193',
    });
    expect(campus.localizacao, isNull);
  });

  test('reconhece título antigo e novo sem unir unidades afastadas', () {
    final antigo = CampusDestino.fromJson(campusJson());
    final novo = CampusDestino.fromJson({
      ...campusJson(),
      'rotuloUnidade': 'Odontologia - José Bonifácio',
    });
    expect(novo.mesmoLocal(antigo.localizacao!), isTrue);
    expect(novo.mesmoLocal(novo.localizacao!), isTrue);
    expect(
      novo.mesmoLocal(
        const LocalizacaoSelecionada(
          ponto: LatLng(-21.3, -50.4),
          nome: 'UNESP · Odontologia - José Bonifácio',
          endereco: 'Outro campus',
        ),
      ),
      isFalse,
    );
    expect(
      novo.mesmoLocal(
        const LocalizacaoSelecionada(
          ponto: LatLng(-21.2, -50.4),
          nome: 'Outra faculdade',
          endereco: 'Rua José Bonifácio, 1193',
        ),
      ),
      isFalse,
    );
  });

  for (final metadados in [
    {'rotuloUnidade': 10},
    {'enderecoCompleto': <String>[]},
    {'rotuloUnidade': 'x' * 151},
    {'enderecoCompleto': 'x' * 501},
  ]) {
    test(
      'rejeita metadados inválidos sem tratá-los como endereço: $metadados',
      () {
        expect(
          () => CampusDestino.fromJson({...campusJson(), ...metadados}),
          throwsFormatException,
        );
      },
    );
  }

  test('aceita os limites de tamanho dos metadados', () {
    final campus = CampusDestino.fromJson({
      ...campusJson(),
      'rotuloUnidade': 'x' * 150,
      'enderecoCompleto': 'x' * 500,
    });
    expect(campus.rotuloUnidade, hasLength(150));
    expect(campus.enderecoCompleto, hasLength(500));
  });

  test(
    'endereço extenso permanece na lista sem ultrapassar o limite da carona',
    () {
      final campus = CampusDestino.fromJson({
        ...campusJson(),
        'rotuloUnidade': 'Odontologia - José Bonifácio',
        'enderecoCompleto': 'x' * 500,
      });
      expect(campus.descricaoEndereco, startsWith('x' * 500));
      expect(campus.localizacao!.endereco, 'Araçatuba, SP, Brasil');
      expect(
        campus.localizacao!.descricaoCompleta.length,
        lessThanOrEqualTo(255),
      );
      expect(campus.localizacao!.ponto, const LatLng(-21.2, -50.4));
    },
  );

  test('inclui endereço até o limite exato de 255 caracteres da carona', () {
    final original = CampusDestino.fromJson(campusJson());
    final fixos =
        original.titulo.length + 3 + ' · Araçatuba, SP, Brasil'.length;
    for (final excesso in [0, 1]) {
      final campus = CampusDestino.fromJson({
        ...campusJson(),
        'enderecoCompleto': 'x' * (255 - fixos + excesso),
      });
      expect(
        campus.localizacao!.descricaoCompleta.length,
        lessThanOrEqualTo(255),
      );
      expect(campus.localizacao!.endereco.startsWith('x'), excesso == 0);
    }
  });
}
