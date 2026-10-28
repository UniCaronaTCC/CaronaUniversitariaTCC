import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/models/carona.dart';
import 'package:uni_carona/models/ponto_embarque.dart';
import 'package:uni_carona/widgets/card_carona_disponivel.dart';

const primeiro = PontoEmbarque(
  id: 1,
  nome: 'Praca central',
  endereco: 'Rua A, 100',
  latitude: -21.2,
  longitude: -50.4,
  ordem: 1,
);
const segundo = PontoEmbarque(
  id: 2,
  nome: 'Outro encontro',
  endereco: 'Rua B, 200',
  latitude: -21.3,
  longitude: -50.5,
  ordem: 2,
);

Carona viagem({
  String motorista = 'Henrique',
  String? fotoMotorista,
  String destino = 'Campus teste',
  List<PontoEmbarque> pontos = const [segundo, primeiro],
  String origem = 'Origem antiga',
  String? modelo = 'Onix',
  String? cor = 'Branco',
  String status = 'ATIVA',
  int vagas = 2,
  double valor = 8,
  bool recorrente = false,
  int? idRecorrencia,
}) => Carona(
  id: 10,
  idMotorista: 50,
  motorista: motorista,
  fotoMotorista: fotoMotorista,
  destino: destino,
  origem: origem,
  pontosEmbarque: pontos,
  dataInicio: DateTime(2099, 10, 22),
  horario: '19:00:37',
  vagas: vagas,
  valor: valor,
  recorrente: recorrente,
  diasSemana: recorrente ? const ['SEG', 'QUA'] : const [],
  idRecorrencia: idRecorrencia,
  diasRecorrencia: const ['SEX', 'SEG'],
  veiculoModelo: modelo,
  veiculoCor: cor,
  status: status,
);

Future<void> abrir(
  WidgetTester tester,
  Carona carona, {
  bool visualHome = true,
  bool recorrencia = false,
  VoidCallback? onTap,
  Widget? acao,
  double escala = 1,
}) => tester.pumpWidget(
  MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(escala)),
      child: child!,
    ),
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: CardCaronaDisponivel(
          carona: carona,
          visualHome: visualHome,
          mostrarRecorrencia: recorrencia,
          onTap: onTap,
          acaoCabecalho: acao,
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('home organiza horario preco motorista veiculo e encontro', (
    tester,
  ) async {
    final carona = viagem();
    await abrir(tester, carona);
    expect(find.text('${carona.dataFormatada}, 19:00'), findsOneWidget);
    expect(find.text('Horário do primeiro encontro'), findsOneWidget);
    expect(find.text('R\$ 8,00'), findsOneWidget);
    expect(find.text('por pessoa'), findsOneWidget);
    expect(find.text('Henrique'), findsOneWidget);
    expect(find.text('H'), findsOneWidget);
    expect(find.text('Onix • Branco'), findsOneWidget);
    expect(
      find.text('Primeiro encontro: Praca central • Rua A, 100'),
      findsOneWidget,
    );
    expect(find.text('Campus teste'), findsOneWidget);
    expect(find.textContaining('Origem antiga'), findsNothing);
    expect(find.text('2 vagas disponíveis'), findsOneWidget);
    expect(
      tester.getTopRight(find.text(carona.valorFormatado)).dx,
      closeTo(
        tester.getTopRight(find.byKey(const ValueKey('card-carona-10'))).dx -
            16,
        0.5,
      ),
    );
    expect(
      tester.getTopLeft(find.text(carona.valorFormatado)).dy,
      lessThan(tester.getTopLeft(find.text('Henrique')).dy),
    );
    expect(
      tester.getTopLeft(find.text(carona.resumoInicio)).dy,
      lessThan(tester.getTopLeft(find.text('Campus teste')).dy),
    );
    expect(carona.pontosEmbarque.first, segundo);
    final linha = tester.getRect(
      find.byKey(const ValueKey('linha-trajeto-home')),
    );
    final encontro = tester.getRect(find.byIcon(Icons.location_on_rounded));
    final destino = tester.getRect(find.byIcon(Icons.school_outlined));
    expect(linha.width, 1);
    expect(linha.height, greaterThan(0));
    expect(linha.center.dx, encontro.center.dx);
    expect(linha.center.dx, destino.center.dx);
    expect(linha.top, greaterThan(encontro.bottom));
    expect(linha.bottom, lessThan(destino.top));
  });

  testWidgets('layout padrao continua intacto sem ativar novo visual', (
    tester,
  ) async {
    await abrir(tester, viagem(), visualHome: false);
    expect(find.text('19:00'), findsOneWidget);
    expect(find.text('2 vagas'), findsOneWidget);
    expect(find.text('por pessoa'), findsNothing);
    expect(find.byType(CircleAvatar), findsNothing);
    expect(find.byKey(const ValueKey('linha-trajeto-home')), findsNothing);
  });

  for (final vagas in [0, 1, 3]) {
    testWidgets('quantidade de vagas $vagas tem rotulo correto', (
      tester,
    ) async {
      await abrir(tester, viagem(vagas: vagas));
      expect(
        find.text(
          vagas == 0
              ? 'Sem vagas disponíveis'
              : vagas == 1
              ? '1 vaga disponível'
              : '3 vagas disponíveis',
        ),
        findsOneWidget,
      );
    });
  }

  for (final status in ['LOTADA', 'EM_ANDAMENTO', 'FINALIZADA', 'CANCELADA']) {
    testWidgets('novo visual preserva status $status', (tester) async {
      await abrir(tester, viagem(status: status));
      expect(find.text(status), findsOneWidget);
      if (status == 'FINALIZADA') {
        expect(
          tester
              .widget<Material>(find.byKey(const ValueKey('card-carona-10')))
              .color,
          const Color(0xFFF1F1F1),
        );
      }
    });
  }

  for (final origem in ['Rua antiga', '  ']) {
    testWidgets('carona sem encontros preserva fallback: $origem', (
      tester,
    ) async {
      await abrir(tester, viagem(pontos: [], origem: origem));
      expect(find.text('Horário'), findsOneWidget);
      expect(
        find.text(
          origem.trim().isEmpty
              ? 'Ponto de encontro não informado'
              : 'Saída cadastrada: Rua antiga',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Primeiro encontro'), findsNothing);
    });
  }

  testWidgets('dados ausentes nao inventam veiculo nome ou destino', (
    tester,
  ) async {
    await abrir(
      tester,
      viagem(motorista: ' ', modelo: null, cor: null, destino: ' '),
    );
    expect(find.text('Motorista'), findsOneWidget);
    expect(find.text('Destino não informado'), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
    expect(find.textContaining('null'), findsNothing);
    expect(find.textContaining('Onix'), findsNothing);
  });

  testWidgets('inicial acentuada e veiculo parcial sao apresentados', (
    tester,
  ) async {
    await abrir(tester, viagem(motorista: 'Álvaro', modelo: 'Argo', cor: ' '));
    expect(find.text('Á'), findsOneWidget);
    expect(find.text('Argo'), findsOneWidget);
    expect(find.text('Argo • '), findsNothing);
  });

  for (final id in [null, 7]) {
    testWidgets('preserva recorrencia com referencia $id', (tester) async {
      await abrir(
        tester,
        viagem(recorrente: id == null, idRecorrencia: id),
        recorrencia: true,
      );
      expect(
        find.text(
          id == null ? 'Recorrência: seg, qua' : 'Recorrência: seg, sex',
        ),
        findsOneWidget,
      );
    });
  }

  testWidgets('respeita opcao de ocultar recorrencia', (tester) async {
    await abrir(tester, viagem(idRecorrencia: 7));
    expect(find.textContaining('Recorrência:'), findsNothing);
  });

  testWidgets('toque no card e acao do cabecalho continuam independentes', (
    tester,
  ) async {
    var detalhes = 0;
    var acoes = 0;
    await abrir(
      tester,
      viagem(),
      onTap: () => detalhes++,
      acao: IconButton(
        onPressed: () => acoes++,
        icon: const Icon(Icons.more_vert),
      ),
    );
    await tester.tap(find.byIcon(Icons.more_vert));
    expect(acoes, 1);
    expect(detalhes, 0);
    await tester.tap(find.text('Henrique'));
    expect(detalhes, 1);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('sem acao de detalhes nao anuncia seta', (tester) async {
    await abrir(tester, viagem());
    expect(find.byIcon(Icons.chevron_right), findsNothing);
  });

  for (final largura in [320.0, 390.0, 600.0]) {
    for (final escala in [1.0, 2.0, 3.0]) {
      testWidgets(
        'textos longos e preco alto cabem em $largura fonte $escala',
        (tester) async {
          tester.view.physicalSize = Size(largura, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final carona = viagem(
            motorista: 'João Henrique de Souza Martins Ferreira',
            destino:
                'Centro Universitario com nome longo - Campus Araçatuba, SP',
            modelo: 'Modelo de veiculo com nome extenso',
            cor: 'Cinza metalico',
            valor: 9999.99,
            idRecorrencia: 7,
            status: 'EM_ANDAMENTO',
          );
          await abrir(
            tester,
            carona,
            escala: escala,
            recorrencia: true,
            onTap: () {},
          );
          expect(find.text(carona.valorFormatado), findsOneWidget);
          expect(tester.takeException(), isNull);
          final linha = tester.getRect(
            find.byKey(const ValueKey('linha-trajeto-home')),
          );
          final encontro = tester.getRect(
            find.byIcon(Icons.location_on_rounded),
          );
          final destino = tester.getRect(find.byIcon(Icons.school_outlined));
          expect(linha.height, greaterThan(0));
          expect(linha.center.dx, encontro.center.dx);
          expect(linha.center.dx, destino.center.dx);
          expect(linha.top, greaterThan(encontro.bottom));
          expect(linha.bottom, lessThan(destino.top));
          expect(
            tester.getBottomLeft(find.text(carona.motorista)).dy,
            lessThan(
              tester
                  .getTopLeft(
                    find.text(
                      'Modelo de veiculo com nome extenso • Cinza metalico',
                    ),
                  )
                  .dy,
            ),
          );
          await tester.ensureVisible(find.text('2 vagas disponíveis'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
