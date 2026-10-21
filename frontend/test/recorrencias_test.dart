import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/home/recorrencias.dart';
import 'package:uni_carona/models/carona.dart';
import 'package:uni_carona/models/recorrencia_carona.dart';

void main() {
  final dados = <String, dynamic>{
    'origem': 'Rua A, 10',
    'destino': 'Faculdade',
    'dataInicio': '2026-09-28',
    'horario': '18:00:00',
    'vagas': 3,
    'valor': 5,
    'diasSemana': ['SEG', 'TER'],
  };
  RecorrenciaCarona modelo(bool ativa) => RecorrenciaCarona.fromJson({
    'idRecorrencia': 7,
    'ativa': ativa,
    'dados': dados,
  });

  test(
    'ocorrência usa sua data concreta e mantém a ligação com a programação',
    () {
      final carona = Carona.fromJson({
        ...dados,
        'idCarona': 42,
        'idRecorrencia': 7,
        'recorrente': false,
        'diasSemana': null,
      });
      expect(carona.idRecorrencia, 7);
      expect(carona.recorrente, false);
      expect(carona.periodoFormatado, isNot(contains('SEG')));
      expect(modelo(true).configuracao.diasSemana, ['SEG', 'TER']);
    },
  );

  testWidgets('motorista pausa e retoma somente sua programação', (
    tester,
  ) async {
    var ativa = true;
    await tester.pumpWidget(
      MaterialApp(
        home: RecorrenciasTela(
          carregar: () async => [modelo(ativa)],
          alterarEstado: (id, valor) async {
            expect(id, 7);
            ativa = valor;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Programação ativa'), findsOneWidget);
    await tester.tap(find.text('PAUSAR'));
    await tester.pumpAndSettle();
    expect(ativa, false);
    expect(find.text('Programação pausada'), findsOneWidget);
    await tester.tap(find.text('RETOMAR'));
    await tester.pumpAndSettle();
    expect(ativa, true);
    expect(find.text('Programação ativa'), findsOneWidget);
  });

  testWidgets('falha de carregamento oferece nova tentativa', (tester) async {
    var falhar = true;
    await tester.pumpWidget(
      MaterialApp(
        home: RecorrenciasTela(
          carregar: () async {
            if (falhar) throw Exception();
            return [];
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tentar novamente'), findsOneWidget);
    falhar = false;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nenhuma programação'), findsOneWidget);
  });

  testWidgets('recorrencia usa primeiro encontro e nao a origem antiga', (
    tester,
  ) async {
    final programacao = RecorrenciaCarona.fromJson({
      'idRecorrencia': 7,
      'ativa': true,
      'dados': {
        ...dados,
        'pontosEmbarque': [
          {
            'endereco': 'Rua B, 20',
            'latitude': -21.3,
            'longitude': -50.5,
            'ordem': 2,
          },
          {
            'nome': 'Praca central',
            'endereco': 'Rua do encontro, 100',
            'latitude': -21.2,
            'longitude': -50.4,
            'ordem': 1,
          },
        ],
      },
    });
    await tester.pumpWidget(
      MaterialApp(home: RecorrenciasTela(carregar: () async => [programacao])),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Primeiro encontro: Praca central • Rua do encontro, 100'),
      findsOneWidget,
    );
    expect(find.text('Horário do primeiro encontro: 18:00'), findsOneWidget);
    expect(find.textContaining('Rua A, 10'), findsNothing);
    expect(find.text('Faculdade'), findsOneWidget);
    expect(find.text('EDITAR'), findsOneWidget);
    expect(find.text('PAUSAR'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('recorrencia antiga mantem saida cadastrada sem encontro falso', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RecorrenciasTela(carregar: () async => [modelo(false)]),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Saída cadastrada: Rua A, 10'), findsOneWidget);
    expect(find.text('Horário: 18:00'), findsOneWidget);
    expect(find.textContaining('Primeiro encontro'), findsNothing);
  });

  testWidgets('recorrencia cabe em tela estreita com fonte ampliada', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: RecorrenciasTela(carregar: () async => [modelo(true)]),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('PAUSAR'), 200);
    expect(tester.takeException(), isNull);
  });
}
