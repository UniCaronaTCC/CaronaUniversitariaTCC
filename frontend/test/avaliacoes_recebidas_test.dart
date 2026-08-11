import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/home/avaliacoes_recebidas.dart';

void main() {
  testWidgets('mostra a media e as avaliacoes recebidas', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AvaliacoesRecebidasTela(
          idUsuario: 1,
          nomeUsuario: 'João',
          carregarAvaliacoes: (idUsuario, pagina) async => {
            'sucesso': true,
            'dados': {
              'media': 4.5,
              'total': 2,
              'pagina': 1,
              'totalPaginas': 1,
              'avaliacoes': [
                {
                  'id': 1,
                  'nota': 5,
                  'comentario': 'Motorista pontual',
                  'criadoEm': '2026-08-10T12:00:00.000Z',
                  'avaliador': {'id': 2, 'nome': 'Maria'},
                },
              ],
            },
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('João'), findsOneWidget);
    expect(find.text('4,5 / 5  ·  2 avaliações'), findsOneWidget);
    expect(find.text('Maria'), findsOneWidget);
    expect(find.text('Motorista pontual'), findsOneWidget);
    expect(find.byIcon(Icons.star), findsNWidgets(6));
  });
}
