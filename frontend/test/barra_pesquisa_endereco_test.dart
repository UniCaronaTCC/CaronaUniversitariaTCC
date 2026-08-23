import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:uni_carona/mapa/models/localizacao_selecionada.dart';
import 'package:uni_carona/mapa/services/endereco_service.dart';
import 'package:uni_carona/mapa/widgets/barra_pesquisa_endereco.dart';

class _EnderecoServiceFalso extends EnderecoService {
  final List<LocalizacaoSelecionada> resultados;
  int quantidadeBuscas = 0;

  _EnderecoServiceFalso(this.resultados);

  @override
  Future<List<LocalizacaoSelecionada>> buscarLocalizacoesPorEndereco(
      String enderecoDigitado, {
        double? latitudeReferencia,
        double? longitudeReferencia,
        String? cidadeReferencia,
        String? estadoReferencia,
      }) async {
    quantidadeBuscas++;
    return resultados;
  }
}

void main() {
  testWidgets(
    'pesquisa enquanto digita e permite selecionar',
        (tester) async {
      const local = LocalizacaoSelecionada(
        ponto: LatLng(-21.2, -50.4),
        nome: 'Shopping Praça Nova Araçatuba',
        endereco: 'Av. Carlos Pereira da Silva, Araçatuba, SP',
      );

      final service = _EnderecoServiceFalso([local]);
      final controller = TextEditingController();

      LocalizacaoSelecionada? selecionado;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BarraPesquisaEndereco(
              controller: controller,
              enderecoService: service,
              onSelecionado: (resultado) {
                selecionado = resultado;
              },
            ),
          ),
        ),
      );

      await tester.enterText(
        find.byType(TextField),
        'shopping praça nova',
      );

      await tester.pump(
        const Duration(milliseconds: 499),
      );

      expect(
        service.quantidadeBuscas,
        0,
      );

      await tester.pump(
        const Duration(milliseconds: 1),
      );

      await tester.pumpAndSettle();

      expect(
        service.quantidadeBuscas,
        1,
      );

      await tester.tap(
        find.text(
          'Shopping Praça Nova Araçatuba',
        ),
      );

      await tester.pump();

      expect(
        selecionado,
        same(local),
      );

      expect(
        controller.text,
        local.descricaoCompleta,
      );

      await tester.enterText(
        find.byType(TextField),
        'unisalesiano',
      );

      await tester.pump(
        const Duration(milliseconds: 500),
      );

      await tester.pumpAndSettle();

      expect(
        service.quantidadeBuscas,
        2,
      );

      controller.dispose();
    },
  );

  testWidgets(
    'avisa quando nenhum endereço é encontrado',
        (tester) async {
      final service = _EnderecoServiceFalso([]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BarraPesquisaEndereco(
              enderecoService: service,
              onSelecionado: (_) {},
            ),
          ),
        ),
      );

      await tester.enterText(
        find.byType(TextField),
        'lugar inexistente',
      );

      await tester.pump(
        const Duration(milliseconds: 500),
      );

      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'Nenhum endereço encontrado',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'não pesquisa com menos de três caracteres',
        (tester) async {
      final service = _EnderecoServiceFalso([]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BarraPesquisaEndereco(
              enderecoService: service,
              onSelecionado: (_) {},
            ),
          ),
        ),
      );

      await tester.enterText(
        find.byType(TextField),
        'ab',
      );

      await tester.pump(
        const Duration(milliseconds: 600),
      );

      expect(
        service.quantidadeBuscas,
        0,
      );
    },
  );
}