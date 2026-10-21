import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/models/carona.dart';
import 'package:uni_carona/models/ponto_embarque.dart';
import 'package:uni_carona/widgets/card_carona_disponivel.dart';
import 'package:uni_carona/widgets/conteudo_detalhes_carona.dart';

const primeiro = PontoEmbarque(
  id: 10,
  nome: 'Praca central',
  endereco: 'Rua A, 100',
  latitude: -21.2,
  longitude: -50.4,
  ordem: 1,
);
const segundo = PontoEmbarque(
  id: 11,
  endereco: 'Rua B, 200',
  latitude: -21.3,
  longitude: -50.5,
  ordem: 2,
);

Carona viagem({
  List<PontoEmbarque> pontos = const [segundo, primeiro],
  String origem = 'Origem antiga diferente dos encontros',
  String destino = 'Campus universitario',
  String status = 'ATIVA',
}) => Carona(
  id: 1,
  origem: origem,
  destino: destino,
  pontosEmbarque: pontos,
  dataInicio: DateTime(2099, 10, 22),
  horario: '18:00:37',
  vagas: 3,
  valor: 12.5,
  recorrente: false,
  diasSemana: const [],
  motorista: 'Motorista',
  status: status,
);

Widget tela(Widget child, {double escala = 1}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(escala)),
    child: child!,
  ),
  home: Scaffold(body: child),
);

void main() {
  test('resumo e lista seguem a ordem salva sem alterar a lista recebida', () {
    final pontos = [segundo, primeiro];
    final carona = viagem(pontos: pontos);
    expect(carona.pontosEmbarqueOrdenados, [primeiro, segundo]);
    expect(
      carona.resumoInicio,
      'Primeiro encontro: Praca central • Rua A, 100',
    );
    expect(carona.rotuloHorario, 'Horário do primeiro encontro');
    expect(pontos, [segundo, primeiro]);
    expect(carona.origem, 'Origem antiga diferente dos encontros');
    expect(carona.horario, '18:00:37');
  });

  test('legado usa saida cadastrada e horario generico sem inventar ponto', () {
    final carona = viagem(pontos: [], origem: '  Rua antiga  ');
    expect(carona.resumoInicio, 'Saída cadastrada: Rua antiga');
    expect(carona.rotuloHorario, 'Horário');
    expect(carona.pontosEmbarqueOrdenados, isEmpty);
  });

  test('legado sem local apresenta ausencia sem endereco falso', () {
    expect(
      viagem(pontos: [], origem: ' ').resumoInicio,
      'Ponto de encontro não informado',
    );
  });

  for (final nome in [null, '', '  ', 'Rua A, 100', ' rua a, 100 ']) {
    test('resumo nao repete endereco quando nome e $nome', () {
      final ponto = PontoEmbarque(
        nome: nome,
        endereco: 'Rua A, 100',
        latitude: -21.2,
        longitude: -50.4,
        ordem: 1,
      );
      expect(
        viagem(pontos: [ponto]).resumoInicio,
        'Primeiro encontro: Rua A, 100',
      );
    });
  }

  for (final pontos in [
    <PontoEmbarque>[primeiro],
    [segundo, primeiro],
  ]) {
    testWidgets('card com ${pontos.length} encontros oculta origem antiga', (
      tester,
    ) async {
      var abriu = false;
      await tester.pumpWidget(
        tela(
          SingleChildScrollView(
            child: CardCaronaDisponivel(
              carona: viagem(pontos: pontos),
              onTap: () => abriu = true,
            ),
          ),
        ),
      );
      expect(find.text('Horário do primeiro encontro'), findsOneWidget);
      expect(find.text('18:00'), findsOneWidget);
      expect(find.text('Campus universitario'), findsOneWidget);
      expect(
        find.text('Primeiro encontro: Praca central • Rua A, 100'),
        findsOneWidget,
      );
      expect(find.textContaining('Origem antiga'), findsNothing);
      await tester.tap(find.byType(CardCaronaDisponivel));
      expect(abriu, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'detalhes com ${pontos.length} encontros ordenados e numerados',
      (tester) async {
        await tester.pumpWidget(
          tela(ConteudoDetalhesCarona(carona: viagem(pontos: pontos))),
        );
        expect(find.text('Origem'), findsNothing);
        expect(find.textContaining('Origem antiga'), findsNothing);
        expect(find.text('Saída cadastrada'), findsNothing);
        expect(find.text('Horário do primeiro encontro'), findsOneWidget);
        expect(find.text('Pontos de encontro'), findsOneWidget);
        expect(find.text('Encontro 1'), findsOneWidget);
        expect(find.text('Rua A, 100'), findsOneWidget);
        if (pontos.length > 1) {
          expect(
            tester.getTopLeft(find.text('Encontro 1')).dy,
            lessThan(tester.getTopLeft(find.text('Encontro 2')).dy),
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('card legado nao anuncia primeiro encontro', (tester) async {
    await tester.pumpWidget(
      tela(
        CardCaronaDisponivel(
          carona: viagem(pontos: [], origem: 'Rua antiga'),
        ),
      ),
    );
    expect(find.text('Saída cadastrada: Rua antiga'), findsOneWidget);
    expect(find.text('Horário'), findsOneWidget);
    expect(find.textContaining('Primeiro encontro'), findsNothing);
    expect(find.textContaining('Saída em'), findsNothing);
  });

  testWidgets('detalhes legados preservam saida sem fabricar encontro', (
    tester,
  ) async {
    await tester.pumpWidget(
      tela(
        ConteudoDetalhesCarona(
          carona: viagem(pontos: [], origem: 'Rua antiga'),
        ),
      ),
    );
    expect(find.text('Saída cadastrada'), findsOneWidget);
    expect(find.text('Rua antiga'), findsOneWidget);
    expect(find.text('Nenhum ponto de encontro cadastrado'), findsOneWidget);
    expect(find.text('Horário'), findsOneWidget);
    expect(find.text('Encontro 1'), findsNothing);
  });

  testWidgets('nome igual ao endereco nao aparece duas vezes nos detalhes', (
    tester,
  ) async {
    const ponto = PontoEmbarque(
      nome: 'Rua A, 100',
      endereco: 'Rua A, 100',
      latitude: -21.2,
      longitude: -50.4,
      ordem: 1,
    );
    await tester.pumpWidget(
      tela(ConteudoDetalhesCarona(carona: viagem(pontos: [ponto]))),
    );
    expect(find.text('Rua A, 100'), findsOneWidget);
  });

  for (final largura in [320.0, 600.0]) {
    for (final detalhes in [false, true]) {
      testWidgets('layout de ${detalhes ? 'detalhes' : 'card'} em $largura', (
        tester,
      ) async {
        tester.view.physicalSize = Size(largura, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const ponto = PontoEmbarque(
          nome: 'Ponto de encontro no estacionamento principal',
          endereco:
              'Avenida Joaquim Pompeu de Toledo, 1234, Centro, Araçatuba, SP',
          latitude: -21.2,
          longitude: -50.4,
          ordem: 1,
        );
        final carona = viagem(
          pontos: [ponto],
          destino:
              'Centro Universitario - Campus com nome longo, Araçatuba, SP',
          status: 'EM_ANDAMENTO',
        );
        await tester.pumpWidget(
          tela(
            detalhes
                ? ConteudoDetalhesCarona(carona: carona, somenteConsulta: true)
                : SingleChildScrollView(
                    child: CardCaronaDisponivel(carona: carona, onTap: () {}),
                  ),
            escala: 1.5,
          ),
        );
        expect(tester.takeException(), isNull);
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -600),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
