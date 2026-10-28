import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:uni_carona/mapa/utils/posicao_no_percurso.dart';

void main() {
  const ponte = [LatLng(-21.2, -50.401), LatLng(-21.2, -50.399)];
  const foraDaPonte = LatLng(-21.199865, -50.4); // Cerca de 15 m ao lado.

  test('ajusta pequeno desvio lateral sem alterar a leitura original', () {
    final visual = posicaoVisualNoPercurso(
      posicao: foraDaPonte,
      percurso: ponte,
      precisao: 25,
      direcao: 90,
    );
    expect(visual.latitude, closeTo(-21.2, 0.0000001));
    expect(visual.longitude, closeTo(-50.4, 0.0000001));
    expect(foraDaPonte.latitude, -21.199865);
  });

  for (final cenario in [
    (
      nome: 'GPS já é preciso para esse afastamento',
      precisao: 3.0,
      direcao: 90.0,
    ),
    (nome: 'GPS muito impreciso', precisao: 80.0, direcao: 90.0),
    (nome: 'direção de uma saída lateral', precisao: 25.0, direcao: 0.0),
    (nome: 'sentido contrário ao trecho', precisao: 25.0, direcao: 270.0),
    (nome: 'sem precisão', precisao: null, direcao: 90.0),
    (nome: 'sem direção confiável', precisao: 25.0, direcao: null),
    (nome: 'direção inválida', precisao: 25.0, direcao: -1.0),
    (nome: 'precisão inválida', precisao: double.nan, direcao: 90.0),
  ]) {
    test('mantém posição recebida: ${cenario.nome}', () {
      expect(
        posicaoVisualNoPercurso(
          posicao: foraDaPonte,
          percurso: ponte,
          precisao: cenario.precisao,
          direcao: cenario.direcao,
        ),
        foraDaPonte,
      );
    });
  }

  test('não cola ao percurso quando o afastamento passa de 20 m', () {
    const distante = LatLng(-21.1997, -50.4);
    expect(
      posicaoVisualNoPercurso(
        posicao: distante,
        percurso: ponte,
        precisao: 40,
        direcao: 90,
      ),
      distante,
    );
  });

  test('não escolhe entre dois trechos paralelos igualmente próximos', () {
    const ambigua = LatLng(-21.19994, -50.4);
    const percurso = [
      ...ponte,
      LatLng(-21.198, -50.399),
      LatLng(-21.198, -50.401),
      LatLng(-21.19988, -50.401),
      LatLng(-21.19988, -50.399),
    ];
    expect(
      posicaoVisualNoPercurso(
        posicao: ambigua,
        percurso: percurso,
        precisao: 20,
        direcao: 90,
      ),
      ambigua,
    );
  });

  test('sem trecho calculado mantém o GPS', () {
    for (final pontos in [
      <LatLng>[],
      [ponte.first],
    ]) {
      expect(
        posicaoVisualNoPercurso(
          posicao: foraDaPonte,
          percurso: pontos,
          precisao: 25,
          direcao: 90,
        ),
        foraDaPonte,
      );
    }
  });
}
