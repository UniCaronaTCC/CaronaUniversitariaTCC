import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/models/campus_destino.dart';
import 'package:uni_carona/services/cidade_pesquisa_service.dart';
import 'package:uni_carona/services/sessao_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const service = CidadePesquisaService();
  const cidade = CidadeCampus('Araçatuba', 'SP');
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('sem preferencia usa modo automatico', () async {
    expect(await service.carregar(1), isNull);
  });

  test('restaura cidade em outra instancia e preserva acentos', () async {
    await service.salvar(1, cidade);
    final salva = await const CidadePesquisaService().carregar(1);
    expect(salva!.mesmaCidade(cidade), isTrue);
    expect(salva.cidade, 'Araçatuba');
    expect(salva.pontoReferencia, isNull);
  });

  test('nao compartilha preferencia com outra conta', () async {
    await service.salvar(1, cidade);
    expect(await service.carregar(2), isNull);
    await service.salvar(2, const CidadeCampus('Manaus', 'AM'));
    expect((await service.carregar(1))!.uf, 'SP');
    expect((await service.carregar(2))!.uf, 'AM');
  });

  test('sair da conta nao apaga a escolha manual', () async {
    await service.salvar(1, cidade);
    await SessaoService.salvar('teste', {'id': 1});
    await SessaoService.limpar();
    expect((await service.carregar(1))!.mesmaCidade(cidade), isTrue);
  });

  test('voltar ao automatico remove apenas a cidade daquela conta', () async {
    FlutterSecureStorage.setMockInitialValues({
      'destino_preferido_v1_1': 'preservar',
    });
    await service.salvar(1, cidade);
    await service.salvar(2, cidade);
    await service.usarLocalizacaoAtual(1);
    expect(await service.carregar(1), isNull);
    expect(await service.carregar(2), isNotNull);
    expect(
      await service.storage.read(key: 'destino_preferido_v1_1'),
      'preservar',
    );
  });

  for (final dado in [
    '{',
    '[]',
    'null',
    '{}',
    jsonEncode({'cidade': 12, 'uf': 'SP'}),
    jsonEncode({'cidade': 'A', 'uf': 'SP'}),
    jsonEncode({'cidade': 'Araçatuba', 'uf': 'XX'}),
    jsonEncode({'cidade': 'Araçatuba', 'uf': 35}),
  ]) {
    test('ignora preferencia invalida $dado', () async {
      FlutterSecureStorage.setMockInitialValues({'cidade_pesquisa_v1_1': dado});
      expect(await service.carregar(1), isNull);
    });
  }

  test('rejeita identificador e cidade invalidos sem gravar', () async {
    expect(() => service.carregar(0), throwsArgumentError);
    expect(() => service.salvar(-1, cidade), throwsArgumentError);
    await expectLater(
      service.salvar(1, const CidadeCampus(' ', 'SP')),
      throwsFormatException,
    );
    await expectLater(
      service.salvar(1, const CidadeCampus('Cidade', 'XX')),
      throwsFormatException,
    );
    expect(await service.carregar(1), isNull);
  });
}
