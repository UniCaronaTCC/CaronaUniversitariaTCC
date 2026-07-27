import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:uni_carona/mapa/models/localizacao_selecionada.dart';
import 'package:uni_carona/mapa/services/endereco_service.dart';
import 'package:uni_carona/mapa/widgets/barra_pesquisa_endereco.dart';

class _EnderecoServiceFalso extends EnderecoService {
  final LocalizacaoSelecionada resultado;

  _EnderecoServiceFalso(this.resultado);

  @override
  Future<List<LocalizacaoSelecionada>> buscarLocalizacoesPorEndereco(
    String enderecoDigitado,
  ) async {
    return [resultado];
  }
}

void main() {
  testWidgets('seleciona um endereço encontrado', (tester) async {
    const local = LocalizacaoSelecionada(
      ponto: LatLng(-21.2, -50.4),
      nome: 'Shopping Praça Nova Araçatuba',
      endereco: 'Av. Carlos Pereira da Silva, Araçatuba, SP',
    );
    LocalizacaoSelecionada? selecionado;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BarraPesquisaEndereco(
            enderecoService: _EnderecoServiceFalso(local),
            onSelecionado: (resultado) {
              selecionado = resultado;
            },
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'shopping praça nova');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Shopping Praça Nova Araçatuba'));
    await tester.pump();

    expect(selecionado, same(local));
    expect(find.text('Shopping Praça Nova Araçatuba'), findsNothing);
  });
}
