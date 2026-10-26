import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:uni_carona/mapa/models/localizacao_selecionada.dart';
import 'package:uni_carona/services/destino_preferido_service.dart';
import 'package:uni_carona/services/sessao_service.dart';

const local = LocalizacaoSelecionada(
  ponto: LatLng(-21.235275, -50.4060626),
  nome: 'UniSALESIANO',
  endereco: 'Rodovia Senador Teotonio Vilela, 3821, Aracatuba',
  cidade: 'Aracatuba',
  estado: 'Sao Paulo',
  pais: 'Brasil',
  rua: 'Rodovia Senador Teotonio Vilela',
  numero: '3821',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const service = DestinoPreferidoService();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('conta sem preferencia inicia sem destino', () async {
    expect(await service.carregar(1), isNull);
  });

  test('restaura todos os dados ao criar outra instancia', () async {
    await service.salvar(1, local);
    final salvo = await const DestinoPreferidoService().carregar(1);
    expect(salvo?.toJson(), local.toJson());
  });

  test(
    'destino aproximado confirmado sem toque preserva precisao ao reabrir',
    () async {
      const rua = LocalizacaoSelecionada(
        ponto: LatLng(-21.2, -50.4),
        endereco: 'Avenida Antonio Cavasana, Aracatuba',
        rua: 'Avenida Antonio Cavasana',
        pontoEspecifico: false,
        precisao: PrecisaoLocalizacao.rua,
        numeroBuscado: '123',
      );
      await service.salvar(1, rua);
      final salvo = await const DestinoPreferidoService().carregar(1);
      expect(salvo!.toJson(), rua.toJson());
      expect(salvo.localConfirmavel, true);
      expect(salvo.numero, isNull);
      expect(
        salvo.avisoPrecisaoPara(ajusteOpcional: true),
        contains('opcional'),
      );
    },
  );

  test('preferencia nao vaza entre contas no mesmo aparelho', () async {
    await service.salvar(1, local);
    expect(await service.carregar(2), isNull);
    expect((await service.carregar(1))?.nome, local.nome);
  });

  test('alteracao substitui destino anterior sem afetar outra conta', () async {
    await service.salvar(1, local);
    await service.salvar(2, local);
    const novo = LocalizacaoSelecionada(
      ponto: LatLng(-21.2, -50.4),
      endereco: 'Outro destino',
    );
    await service.salvar(1, novo);
    expect((await service.carregar(1))?.endereco, 'Outro destino');
    expect((await service.carregar(2))?.nome, local.nome);
  });

  test('sair da sessao preserva preferencia da conta', () async {
    await service.salvar(1, local);
    await SessaoService.salvar('token-sintetico', {'id': 1});
    await SessaoService.limpar();
    expect((await service.carregar(1))?.toJson(), local.toJson());
  });

  for (final dado in ['{invalido', '[]', 'null', '{"latitude":10}']) {
    test('ignora preferencia corrompida: $dado', () async {
      FlutterSecureStorage.setMockInitialValues({
        'destino_preferido_v1_1': dado,
      });
      expect(await service.carregar(1), isNull);
    });
  }

  for (final alteracao in [
    {'latitude': 91},
    {'longitude': -181},
    {'nome': 42},
    {'endereco': ''},
    {'pontoEspecifico': 'sim'},
    {'latitude': 'texto'},
  ]) {
    test('descarta campo salvo invalido: $alteracao', () async {
      FlutterSecureStorage.setMockInitialValues({
        'destino_preferido_v1_1': jsonEncode({...local.toJson(), ...alteracao}),
      });
      expect(await service.carregar(1), isNull);
    });
  }

  test('nao aceita endereco vazio nem identifica conta por nome', () async {
    expect(() => service.salvar(0, local), throwsArgumentError);
    expect(
      () => service.salvar(
        1,
        const LocalizacaoSelecionada(ponto: LatLng(-21, -50), endereco: ' '),
      ),
      throwsFormatException,
    );
    expect(await service.carregar(1), isNull);
  });
}
