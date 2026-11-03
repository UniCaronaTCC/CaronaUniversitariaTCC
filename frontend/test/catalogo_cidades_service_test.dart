import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/models/campus_destino.dart';
import 'package:uni_carona/services/catalogo_cidades_service.dart';

class BundleCidades extends CachingAssetBundle {
  final String texto;
  BundleCidades(this.texto);
  @override
  Future<String> loadString(String key, {bool cache = true}) async => texto;
  @override
  Future<ByteData> load(String key) async => throw UnsupportedError('load');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'catalogo embarcado cobre os estados e preserva cidades homonimas',
    () async {
      final cidades = await const CatalogoCidadesService().listar();
      expect(cidades.length, greaterThanOrEqualTo(5500));
      expect(
        cidades.map((c) => c.uf).toSet(),
        CidadeCampus.estados.keys.toSet(),
      );
      expect(
        cidades.where((c) => c.cidade == 'Araçatuba' && c.uf == 'SP'),
        hasLength(1),
      );
      expect(
        cidades.where((c) => c.cidade == 'Brasília' && c.uf == 'DF'),
        hasLength(1),
      );
      expect(
        cidades
            .where((c) => c.cidade == 'Bom Jesus')
            .map((c) => c.uf)
            .toSet()
            .length,
        greaterThan(1),
      );
      expect(
        cidades
            .map((c) => '${normalizarDestino(c.cidade)}|${c.uf}')
            .toSet()
            .length,
        cidades.length,
      );
      expect(() => cidades.clear(), throwsUnsupportedError);
      expect(
        identical(cidades, await const CatalogoCidadesService().listar()),
        isTrue,
      );
    },
  );

  test('ordena ignorando acentos sem perder o nome oficial', () async {
    final service = CatalogoCidadesService(
      bundle: BundleCidades(
        jsonEncode({
          'municipios': [
            {'id': 2, 'nome': 'Zortéa', 'uf': 'SC'},
            {'id': 1, 'nome': 'Águas', 'uf': 'SP'},
          ],
        }),
      ),
    );
    expect((await service.listar()).map((c) => c.cidade), ['Águas', 'Zortéa']);
  });

  for (final dado in [
    '{}',
    '[]',
    '{',
    jsonEncode({'municipios': []}),
    jsonEncode({
      'municipios': [
        {'id': 1, 'nome': 'Cidade', 'uf': 'XX'},
      ],
    }),
    jsonEncode({
      'municipios': [
        {'id': 0, 'nome': 'Cidade', 'uf': 'SP'},
      ],
    }),
    jsonEncode({
      'municipios': [
        {'id': 1, 'nome': 42, 'uf': 'SP'},
      ],
    }),
    jsonEncode({
      'municipios': [
        {'id': 1, 'nome': 'Cidade', 'uf': 'SP'},
        {'id': 2, 'nome': 'CIDADE', 'uf': 'SP'},
      ],
    }),
  ]) {
    test('rejeita catalogo invalido $dado', () async {
      final service = CatalogoCidadesService(bundle: BundleCidades(dado));
      await expectLater(service.listar(), throwsFormatException);
    });
  }
}
