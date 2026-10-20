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
}
