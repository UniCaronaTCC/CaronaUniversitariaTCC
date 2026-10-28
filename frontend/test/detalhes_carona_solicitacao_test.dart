import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uni_carona/home/detalhes_carona.dart';
import 'package:uni_carona/models/carona.dart';
import 'package:uni_carona/models/ponto_embarque.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/services/mensagem_service.dart';
import 'package:uni_carona/services/solicitacao_service.dart';

Carona caronaTeste({
  int id = 1,
  String status = 'ATIVA',
  bool recorrente = false,
}) => Carona(
  id: id,
  idMotorista: 7,
  motorista: 'Motorista teste',
  origem: 'Centro',
  destino: 'Campus teste',
  dataInicio: DateTime(2026, 11, 1),
  horario: '19:00:00',
  vagas: status == 'LOTADA' ? 0 : 3,
  valor: 5,
  recorrente: recorrente,
  diasSemana: const [],
  status: status,
  pontosEmbarque: const [
    PontoEmbarque(
      id: 10,
      nome: 'Encontro teste',
      endereco: 'Praca central',
      latitude: -21.2,
      longitude: -50.4,
      ordem: 1,
    ),
  ],
);

Map<String, dynamic> solicitacaoTeste({
  int idCarona = 1,
  String status = 'PENDENTE',
  bool paga = false,
}) => {
  'id': 23,
  'status': status,
  'pagamentoConfirmado': paga,
  'motorista': {'nome': 'Motorista teste'},
  'carona': {
    'id': idCarona,
    'destino': 'Campus teste',
    'dataInicio': '2026-11-01',
    'horario': '19:00:00',
    'valor': 5,
    'status': 'ATIVA',
  },
};

http.Response lista(List<Map<String, dynamic>> dados) => http.Response(
  jsonEncode({'sucesso': true, 'dados': dados}),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Future<void> abrir(WidgetTester tester, {Carona? carona, Key? key}) =>
    tester.pumpWidget(
      MaterialApp(
        home: DetalhesCaronaTela(key: key, carona: carona ?? caronaTeste()),
      ),
    );

Future<void> executar(
  Future<void> Function() acao,
  http.Client Function() criarCliente,
) async {
  final cliente = criarCliente();
  try {
    await http.runWithClient(
      acao,
      () => MockClient((request) async {
        if (request.url.path != '/solicitacoes/enviadas' &&
            !(request.method == 'POST' &&
                request.url.path.endsWith('/solicitacoes'))) {
          return lista([]);
        }
        return request.method == 'POST'
            ? cliente.post(
                request.url,
                headers: request.headers,
                body: request.body,
              )
            : cliente.get(request.url, headers: request.headers);
      }),
    );
  } finally {
    SolicitacaoService.pararContadorSolicitacoesPendentes();
    await MensagemService.pararContadorMensagensNaoLidas();
    cliente.close();
  }
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    AuthService.usuarioLogado = {'id': 42, 'nome': 'Passageiro teste'};
    AuthService.tokenUsuarioLogado = 'token-teste';
  });

  tearDown(() {
    AuthService.usuarioLogado = null;
    AuthService.tokenUsuarioLogado = null;
  });

  testWidgets('oculta botao enquanto consulta a solicitacao', (tester) async {
    final resposta = Completer<http.Response>();
    await executar(() async {
      await abrir(tester);
      expect(find.text('SOLICITAR VAGA'), findsNothing);
      expect(find.text('Consultando solicitação...'), findsOneWidget);
      resposta.complete(lista([]));
      await tester.pumpAndSettle();
      expect(find.text('SOLICITAR VAGA'), findsOneWidget);
    }, () => MockClient((_) => resposta.future));
  });

  for (final corpo in [
    '',
    '<html>proxy indisponivel</html>',
    '[]',
    '{}',
    '{"dados":null}',
    '{"dados":{}}',
    '{"sucesso":false,"dados":[]}',
    '{"dados":[null]}',
    '{"dados":["registro incompleto"]}',
    '{"dados":[{}]}',
    jsonEncode({
      'dados': [solicitacaoTeste(idCarona: 2), null],
    }),
  ]) {
    testWidgets('resposta 200 invalida nao libera botao: $corpo', (
      tester,
    ) async {
      await executar(() async {
        await abrir(tester);
        await tester.pumpAndSettle();
        expect(find.text('SOLICITAR VAGA'), findsNothing);
        expect(
          find.text('Não foi possível consultar sua solicitação.'),
          findsOneWidget,
        );
        expect(find.text('Tentar novamente'), findsOneWidget);
      }, () => MockClient((_) async => http.Response(corpo, 200)));
    });
  }

  testWidgets(
    'nova tentativa apos resposta invalida recupera solicitacao existente',
    (tester) async {
      var invalida = true;
      await executar(
        () async {
          await abrir(tester);
          await tester.pumpAndSettle();
          expect(find.text('Tentar novamente'), findsOneWidget);
          invalida = false;
          await tester.tap(find.text('Tentar novamente'));
          await tester.pumpAndSettle();
          expect(find.text('Carona já solicitada'), findsOneWidget);
          expect(find.text('SOLICITAR VAGA'), findsNothing);
          expect(find.text('Tentar novamente'), findsNothing);
        },
        () => MockClient(
          (_) async =>
              invalida ? http.Response('{}', 200) : lista([solicitacaoTeste()]),
        ),
      );
    },
  );

  for (final caso in [
    (
      'PENDENTE',
      false,
      'Carona já solicitada',
      'Aguardando resposta do motorista.',
    ),
    (
      'ACEITA',
      false,
      'Solicitação aceita',
      'Aguardando pagamento. Acompanhe em Caronas.',
    ),
    ('ACEITA', true, 'Vaga confirmada', 'Seu pagamento foi confirmado.'),
  ]) {
    testWidgets('substitui botao pelo estado ${caso.$3}', (tester) async {
      await executar(
        () async {
          await abrir(tester);
          await tester.pumpAndSettle();
          expect(find.text('SOLICITAR VAGA'), findsNothing);
          expect(find.text(caso.$3), findsOneWidget);
          expect(find.text(caso.$4), findsOneWidget);
          expect(
            find.byWidgetPredicate((widget) => widget is ElevatedButton),
            findsNothing,
          );
        },
        () => MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/solicitacoes/enviadas');
          expect(request.headers['Authorization'], 'Bearer token-teste');
          return lista([solicitacaoTeste(status: caso.$1, paga: caso.$2)]);
        }),
      );
    });
  }

  for (final status in [
    'RECUSADA',
    'CANCELADA_PASSAGEIRO',
    'CANCELADA_MOTORISTA',
    'EXPIRADA',
  ]) {
    testWidgets('permite nova tentativa apos $status', (tester) async {
      await executar(
        () async {
          await abrir(tester);
          await tester.pumpAndSettle();
          expect(find.text('SOLICITAR VAGA'), findsOneWidget);
          expect(find.text('Carona já solicitada'), findsNothing);
        },
        () =>
            MockClient((_) async => lista([solicitacaoTeste(status: status)])),
      );
    });
  }

  testWidgets('solicitacao de outra carona nao esconde botao', (tester) async {
    await executar(() async {
      await abrir(tester);
      await tester.pumpAndSettle();
      expect(find.text('SOLICITAR VAGA'), findsOneWidget);
    }, () => MockClient((_) async => lista([solicitacaoTeste(idCarona: 2)])));
  });

  testWidgets('reabertura consulta novamente em vez de usar estado local', (
    tester,
  ) async {
    var jaSolicitada = false;
    await executar(
      () async {
        await abrir(tester);
        await tester.pumpAndSettle();
        expect(find.text('SOLICITAR VAGA'), findsOneWidget);
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        jaSolicitada = true;
        await abrir(tester);
        await tester.pumpAndSettle();
        expect(find.text('SOLICITAR VAGA'), findsNothing);
        expect(find.text('Carona já solicitada'), findsOneWidget);
      },
      () => MockClient(
        (_) async => lista(jaSolicitada ? [solicitacaoTeste()] : []),
      ),
    );
  });

  testWidgets('falha de consulta nao libera envio e permite tentar novamente', (
    tester,
  ) async {
    var falhar = true;
    await executar(
      () async {
        await abrir(tester);
        await tester.pumpAndSettle();
        expect(find.text('SOLICITAR VAGA'), findsNothing);
        expect(
          find.text('Não foi possível consultar sua solicitação.'),
          findsOneWidget,
        );
        falhar = false;
        await tester.tap(find.text('Tentar novamente'));
        await tester.pumpAndSettle();
        expect(find.text('Carona já solicitada'), findsOneWidget);
        expect(find.text('SOLICITAR VAGA'), findsNothing);
      },
      () => MockClient((_) async {
        if (falhar) throw http.ClientException('sem conexao');
        return lista([solicitacaoTeste()]);
      }),
    );
  });

  testWidgets('consulta tem limite de espera e ignora resposta tardia', (
    tester,
  ) async {
    final resposta = Completer<http.Response>();
    await executar(() async {
      await abrir(tester);
      await tester.pump(const Duration(seconds: 21));
      await tester.pumpAndSettle();
      expect(find.text('Tentar novamente'), findsOneWidget);
      expect(find.text('SOLICITAR VAGA'), findsNothing);
      resposta.complete(lista([]));
      await tester.pumpAndSettle();
      expect(find.text('SOLICITAR VAGA'), findsNothing);
    }, () => MockClient((_) => resposta.future));
  });

  testWidgets('sucesso do envio remove botao imediatamente', (tester) async {
    var envios = 0;
    await executar(
      () async {
        await abrir(tester);
        await tester.pumpAndSettle();
        await tester.tap(find.text('SOLICITAR VAGA'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Encontro teste').last);
        await tester.pumpAndSettle();
        expect(find.text('SOLICITAR VAGA'), findsNothing);
        expect(find.text('Carona já solicitada'), findsOneWidget);
        expect(find.text('Aguardando resposta do motorista.'), findsOneWidget);
      },
      () => MockClient((request) async {
        if (request.method == 'GET') return lista([]);
        envios++;
        expect(request.url.path, '/caronas/1/solicitacoes');
        expect(jsonDecode(request.body)['idPontoEmbarque'], 10);
        return http.Response('{"sucesso":true,"dados":{"id":23}}', 201);
      }),
    );
    expect(envios, 1);
  });

  testWidgets('conflito no envio reconcilia estado sem repetir POST', (
    tester,
  ) async {
    var envios = 0;
    await executar(
      () async {
        await abrir(tester);
        await tester.pumpAndSettle();
        await tester.tap(find.text('SOLICITAR VAGA'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Encontro teste').last);
        await tester.pumpAndSettle();
        expect(find.text('Carona já solicitada'), findsOneWidget);
        expect(find.text('SOLICITAR VAGA'), findsNothing);
      },
      () => MockClient((request) async {
        if (request.method == 'GET') {
          return lista(envios == 0 ? [] : [solicitacaoTeste()]);
        }
        envios++;
        return http.Response(
          '{"message":"Voce ja solicitou vaga nesta carona"}',
          409,
        );
      }),
    );
    expect(envios, 1);
  });

  testWidgets('fechar tela antes da resposta nao causa setState apos dispose', (
    tester,
  ) async {
    final resposta = Completer<http.Response>();
    await executar(() async {
      await abrir(tester);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      resposta.complete(lista([solicitacaoTeste()]));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }, () => MockClient((_) => resposta.future));
  });

  testWidgets('aceite recorrente nao promete pagamento indisponivel', (
    tester,
  ) async {
    await executar(
      () async {
        await abrir(tester, carona: caronaTeste(recorrente: true));
        await tester.pumpAndSettle();
        expect(find.text('Solicitação aceita'), findsOneWidget);
        expect(find.text('Acompanhe os detalhes em Caronas.'), findsOneWidget);
        expect(find.textContaining('Aguardando pagamento'), findsNothing);
      },
      () =>
          MockClient((_) async => lista([solicitacaoTeste(status: 'ACEITA')])),
    );
  });

  testWidgets('aviso cabe em tela estreita com fonte ampliada', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await executar(() async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: DetalhesCaronaTela(carona: caronaTeste()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Carona já solicitada'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, () => MockClient((_) async => lista([solicitacaoTeste()])));
  });

  testWidgets('outra conta nao herda solicitacao do usuario anterior', (
    tester,
  ) async {
    await executar(
      () async {
        await abrir(tester);
        await tester.pumpAndSettle();
        expect(find.text('Carona já solicitada'), findsOneWidget);
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        AuthService.usuarioLogado = {'id': 43, 'nome': 'Outro passageiro'};
        AuthService.tokenUsuarioLogado = 'token-outro';
        await abrir(tester);
        await tester.pumpAndSettle();
        expect(find.text('SOLICITAR VAGA'), findsOneWidget);
        expect(find.text('Carona já solicitada'), findsNothing);
      },
      () => MockClient(
        (request) async => lista(
          request.headers['Authorization'] == 'Bearer token-teste'
              ? [solicitacaoTeste()]
              : [],
        ),
      ),
    );
  });

  testWidgets('trocar carona descarta consulta antiga ainda pendente', (
    tester,
  ) async {
    var consultas = 0;
    final antiga = Completer<http.Response>();
    await executar(
      () async {
        await abrir(tester);
        await abrir(tester, carona: caronaTeste(id: 2));
        await tester.pumpAndSettle();
        expect(find.text('SOLICITAR VAGA'), findsOneWidget);
        antiga.complete(lista([solicitacaoTeste()]));
        await tester.pumpAndSettle();
        expect(find.text('SOLICITAR VAGA'), findsOneWidget);
        expect(find.text('Carona já solicitada'), findsNothing);
        expect(tester.takeException(), isNull);
      },
      () => MockClient(
        (_) => ++consultas == 1 ? antiga.future : Future.value(lista([])),
      ),
    );
  });

  for (final status in ['LOTADA', 'EM_ANDAMENTO']) {
    testWidgets('$status mostra solicitacao existente sem botao', (
      tester,
    ) async {
      await executar(() async {
        await abrir(tester, carona: caronaTeste(status: status));
        await tester.pumpAndSettle();
        expect(find.text('Carona já solicitada'), findsOneWidget);
        expect(find.text('SOLICITAR VAGA'), findsNothing);
      }, () => MockClient((_) async => lista([solicitacaoTeste()])));
    });

    testWidgets('$status sem solicitacao nao oferece envio indisponivel', (
      tester,
    ) async {
      await executar(() async {
        await abrir(tester, carona: caronaTeste(status: status));
        await tester.pumpAndSettle();
        expect(find.text('SOLICITAR VAGA'), findsNothing);
        expect(
          find.text('Esta carona não está disponível para solicitações.'),
          findsOneWidget,
        );
      }, () => MockClient((_) async => lista([])));
    });
  }

  testWidgets('falha no envio e na consulta nao libera outro envio', (
    tester,
  ) async {
    var envios = 0;
    await executar(
      () async {
        await abrir(tester);
        await tester.pumpAndSettle();
        await tester.tap(find.text('SOLICITAR VAGA'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Encontro teste').last);
        await tester.pumpAndSettle();
        expect(find.text('SOLICITAR VAGA'), findsNothing);
        expect(find.text('Tentar novamente'), findsOneWidget);
      },
      () => MockClient((request) async {
        if (request.method == 'POST') {
          envios++;
          throw http.ClientException('resposta do envio perdida');
        }
        if (envios > 0) throw http.ClientException('sem conexao');
        return lista([]);
      }),
    );
    expect(envios, 1);
  });

  testWidgets('falha no envio com consulta vazia permite tentar novamente', (
    tester,
  ) async {
    var envios = 0;
    await executar(
      () async {
        await abrir(tester);
        await tester.pumpAndSettle();
        await tester.tap(find.text('SOLICITAR VAGA'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Encontro teste').last);
        await tester.pumpAndSettle();
        expect(find.text('SOLICITAR VAGA'), findsOneWidget);
        expect(find.text('Carona já solicitada'), findsNothing);
      },
      () => MockClient((request) async {
        if (request.method == 'POST') {
          envios++;
          return http.Response('{"message":"Ponto invalido"}', 400);
        }
        return lista([]);
      }),
    );
    expect(envios, 1);
  });

  testWidgets('envio em andamento fica desabilitado e nao repete POST', (
    tester,
  ) async {
    var envios = 0;
    final envio = Completer<http.Response>();
    await executar(
      () async {
        await abrir(tester);
        await tester.pumpAndSettle();
        await tester.tap(find.text('SOLICITAR VAGA'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Encontro teste').last);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('ENVIANDO...'), findsOneWidget);
        expect(
          tester
              .widget<ElevatedButton>(
                find.byWidgetPredicate((widget) => widget is ElevatedButton),
              )
              .onPressed,
          isNull,
        );
        envio.complete(http.Response('{"dados":{"id":23}}', 201));
        await tester.pumpAndSettle();
        expect(find.text('Carona já solicitada'), findsOneWidget);
        expect(
          find.byWidgetPredicate((widget) => widget is ElevatedButton),
          findsNothing,
        );
      },
      () => MockClient((request) {
        if (request.method == 'POST') {
          envios++;
          return envio.future;
        }
        return Future.value(lista([]));
      }),
    );
    expect(envios, 1);
  });

  testWidgets('cancelar selecao de encontro nao envia solicitacao', (
    tester,
  ) async {
    var envios = 0;
    await executar(
      () async {
        await abrir(tester);
        await tester.pumpAndSettle();
        await tester.tap(find.text('SOLICITAR VAGA'));
        await tester.pumpAndSettle();
        Navigator.of(
          tester.element(find.text('Escolha o ponto de embarque')),
        ).pop();
        await tester.pumpAndSettle();
        expect(find.text('SOLICITAR VAGA'), findsOneWidget);
      },
      () => MockClient((request) async {
        if (request.method == 'POST') envios++;
        return lista([]);
      }),
    );
    expect(envios, 0);
  });

  testWidgets('erro de consulta cabe em tela estreita com fonte ampliada', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await executar(
      () async {
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: DetalhesCaronaTela(carona: caronaTeste()),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Tentar novamente'), findsOneWidget);
        expect(find.text('SOLICITAR VAGA'), findsNothing);
        expect(tester.takeException(), isNull);
      },
      () => MockClient(
        (_) async => http.Response('<html>indisponivel</html>', 503),
      ),
    );
  });
}
