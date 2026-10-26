import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:uni_carona/mapa/models/localizacao_selecionada.dart';

void main() {
  for (final precisao in PrecisaoLocalizacao.values) {
    test('encontro distingue rua de regiao $precisao', () {
      final local = LocalizacaoSelecionada(
        ponto: const LatLng(-21, -50),
        endereco: 'Local retornado',
        pontoEspecifico: false,
        precisao: precisao,
      );
      expect(
        local.pontoDeEncontroValido,
        precisao == PrecisaoLocalizacao.rua ||
            precisao == PrecisaoLocalizacao.ponto,
      );
      expect(
        LocalizacaoSelecionada.fromJson(local.toJson()).precisao,
        precisao,
      );
    });
  }
  test('encontro rejeita endereco vazio e coordenadas invalidas', () {
    for (final local in [
      const LocalizacaoSelecionada(ponto: LatLng(-21, -50), endereco: '  '),
      const LocalizacaoSelecionada(
        ponto: LatLng(double.nan, -50),
        endereco: 'Rua',
        precisao: PrecisaoLocalizacao.rua,
      ),
    ]) {
      expect(local.pontoDeEncontroValido, false);
    }
  });
  test('numero igual em outra rua continua nao confirmado', () {
    const local = LocalizacaoSelecionada(
      ponto: LatLng(-21, -50),
      endereco: 'Rua Outra, 123',
      rua: 'Rua Outra',
      numero: '123',
    );
    final marcado = local.comNumeroBuscado(
      '123',
      logradouroBuscado: 'Rua Brasil',
    );
    expect(marcado.exigeAjusteNoMapa, true);
    expect(
      LocalizacaoSelecionada.fromJson(marcado.toJson()).logradouroBuscado,
      'Rua Brasil',
    );
    expect(
      local
          .comNumeroBuscado('123', logradouroBuscado: 'R. Outra')
          .exigeAjusteNoMapa,
      false,
    );
  });
  const legado = LocalizacaoSelecionada(
    ponto: LatLng(-21, -50),
    endereco: 'Rua salva',
  );
  test('destino legado continua compativel sem novos campos', () {
    final json = legado.toJson();
    expect(json.containsKey('precisao'), false);
    final carregado = LocalizacaoSelecionada.fromJson(json);
    expect(carregado.exigeAjusteNoMapa, false);
    expect(carregado.descricaoCompleta, legado.descricaoCompleta);
  });
  for (final precisao in PrecisaoLocalizacao.values) {
    test('preserva precisao $precisao ao salvar e reabrir', () {
      final local = LocalizacaoSelecionada(
        ponto: const LatLng(-21, -50),
        endereco: 'Rua',
        precisao: precisao,
      );
      final carregado = LocalizacaoSelecionada.fromJson(local.toJson());
      expect(carregado.precisao, precisao);
      expect(
        carregado.exigeAjusteNoMapa,
        precisao != PrecisaoLocalizacao.ponto,
      );
    });
  }
  test('nao inventa numero solicitado nem altera endereco retornado', () {
    final local = legado.comNumeroBuscado('123');
    expect(local.numero, isNull);
    expect(local.endereco, 'Rua salva');
    expect(local.numeroNaoConfirmado, true);
    expect(local.exigeAjusteNoMapa, true);
    expect(local.avisoPrecisao, contains('123'));
    expect(
      LocalizacaoSelecionada.fromJson(local.toJson()).numeroBuscado,
      '123',
    );
  });
  test('numero retornado igual ao solicitado nao exige ajuste adicional', () {
    const local = LocalizacaoSelecionada(
      ponto: LatLng(-21, -50),
      endereco: 'Rua 123A',
      numero: '123a',
    );
    expect(local.comNumeroBuscado('123A').exigeAjusteNoMapa, false);
    expect(local.comNumeroBuscado('321').exigeAjusteNoMapa, true);
  });
  test('precisao invalida no armazenamento nao e tratada como ponto exato', () {
    expect(
      () => LocalizacaoSelecionada.fromJson({
        ...legado.toJson(),
        'precisao': 'invalida',
      }),
      throwsFormatException,
    );
  });
}
