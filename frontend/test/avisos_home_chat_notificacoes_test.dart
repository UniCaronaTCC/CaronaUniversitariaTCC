import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/home/conversa_detalhe.dart';
import 'package:uni_carona/home/detalhes_carona.dart';
import 'package:uni_carona/home/notificacoes.dart';
import 'package:uni_carona/home/selecionar_destino.dart';
import 'package:uni_carona/home/tela_inicial.dart';
import 'package:uni_carona/mapa/models/localizacao_selecionada.dart';
import 'package:uni_carona/models/conversa.dart';
import 'package:uni_carona/models/mensagem.dart';
import 'package:uni_carona/models/notificacao.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/services/destino_preferido_service.dart';
import 'package:uni_carona/widgets/aviso_app.dart';
import 'package:uni_carona/widgets/card_destino_home.dart';

import 'avisos_caronas_solicitacoes_test.dart' as avisos;
import 'conversa_estado_test.dart' show conversaJson;
import 'destino_home_test.dart' as destinos;
import 'notificacoes_test.dart' as notificacoes;

class DestinoControlado extends DestinoPreferidoService {
  Future<LocalizacaoSelecionada?> Function()? leitura;
  Future<void> Function()? gravacao;
  @override
  Future<LocalizacaoSelecionada?> carregar(int idUsuario) =>
      leitura?.call() ?? Future.value(destinos.local);
  @override
  Future<void> salvar(int idUsuario, LocalizacaoSelecionada destino) async {
    await gravacao?.call();
  }
}

class CentralControlada extends notificacoes.NotificacoesFake {
  Future<Map<String, dynamic>> Function()? consulta;
  @override
  Future<Map<String, dynamic>> listar({int? antesDe}) {
    consultas++;
    return consulta?.call() ??
        Future.value({'sucesso': true, 'dados': primeira});
  }
}

void conferirErro(WidgetTester tester) {
  avisos.conferirAviso(tester, false);
  expect(
    tester.widget<SnackBar>(find.byType(SnackBar)).duration,
    const Duration(seconds: 5),
  );
}

Future<void> executar(WidgetTester tester, Future<void> Function() corpo) =>
    avisos.executar(
      tester,
      corpo,
      (_) async => avisos.resposta({'sucesso': true, 'dados': []}),
    );

Future<void> cobrirOuRemover(
  WidgetTester tester,
  GlobalKey<NavigatorState> navegador,
  bool remover,
) async {
  if (remover) {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Outra tela'))),
    );
  } else {
    unawaited(
      navegador.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Outra tela')),
        ),
      ),
    );
  }
  await tester.pumpAndSettle();
}

void conferirOutraTela(WidgetTester tester) {
  expect(find.text('Outra tela'), findsOneWidget);
  expect(find.byType(AvisoApp), findsNothing);
  expect(tester.takeException(), isNull);
}

Future<void> abrirChat(
  WidgetTester tester,
  Future<Map<String, dynamic>> Function(int) carregar, {
  GlobalKey<NavigatorState>? navegador,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navegador,
      home: ConversaDetalheTela(
        conversa: Conversa.fromJson(conversaJson('ATIVA')),
        idUsuario: 1,
        usarRealtime: false,
        carregarCarona: carregar,
        carregarMensagens: () async => {'sucesso': true, 'dados': <Mensagem>[]},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    AuthService.usuarioLogado = {'id': 7, 'nome': 'Pessoa teste'};
    AuthService.tokenUsuarioLogado = 'token-sintetico';
  });
  tearDown(() {
    AuthService.usuarioLogado = null;
    AuthService.tokenUsuarioLogado = null;
  });

  testWidgets(
    'Home usa vermelho ao falhar leitura sem impedir a escolha de destino',
    (tester) => executar(tester, () async {
      final service = DestinoControlado()
        ..leitura = () async => throw StateError('Falha sintetica');
      await tester.pumpWidget(
        MaterialApp(
          home: TelaInicial(
            nomeUsuario: 'Teste',
            destinoPreferidoService: service,
          ),
        ),
      );
      await tester.pumpAndSettle();
      conferirErro(tester);
      expect(
        find.text('Não foi possível carregar seu destino salvo'),
        findsOneWidget,
      );
      expect(
        tester.widget<CardDestinoHome>(find.byType(CardDestinoHome)).onTap,
        isNotNull,
      );
    }),
  );

  for (final remover in [false, true]) {
    for (final salvar in [false, true]) {
      testWidgets(
        'falha tardia da Home salvar=$salvar remover=$remover',
        (tester) => executar(tester, () async {
          final navegador = GlobalKey<NavigatorState>();
          final pendente = Completer<void>();
          final service = DestinoControlado();
          if (salvar) {
            service.gravacao = () async {
              await pendente.future;
              throw StateError('Gravacao indisponivel');
            };
          } else {
            service.leitura = () async {
              await pendente.future;
              throw StateError('Leitura indisponivel');
            };
          }
          await tester.pumpWidget(
            MaterialApp(
              navigatorKey: navegador,
              home: TelaInicial(
                nomeUsuario: 'Teste',
                destinoPreferidoService: service,
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (salvar) {
            await tester.tap(find.byType(CardDestinoHome));
            await tester.pumpAndSettle();
            expect(find.byType(SelecionarDestinoTela), findsOneWidget);
            navegador.currentState!.pop(destinos.novo);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 500));
          }
          await cobrirOuRemover(tester, navegador, remover);
          pendente.complete();
          await tester.pumpAndSettle();
          conferirOutraTela(tester);
          if (salvar && !remover) {
            navegador.currentState!.pop();
            await tester.pumpAndSettle();
            expect(
              tester
                  .widget<CardDestinoHome>(find.byType(CardDestinoHome))
                  .destino,
              destinos.local.descricaoCompleta,
            );
          }
        }),
      );
    }
  }

  for (final situacao in ['falha', 'excecao', 'timeout', 'dados invalidos']) {
    testWidgets(
      'chat usa vermelho e preserva conversa: $situacao',
      (tester) => executar(tester, () async {
        final pendente = Completer<Map<String, dynamic>>();
        var consultas = 0;
        await abrirChat(tester, (_) {
          consultas++;
          return switch (situacao) {
            'excecao' => Future.error(StateError('Falha sintetica')),
            'timeout' => pendente.future,
            'dados invalidos' => Future.value({
              'sucesso': true,
              'dados': 'invalido',
            }),
            _ => Future.value({
              'sucesso': false,
              'mensagem': 'Carona indisponivel',
            }),
          };
        });
        await tester.tap(
          find.byKey(const ValueKey('cabecalho-detalhes-carona')),
        );
        await tester.pump();
        if (situacao == 'timeout') {
          await tester.pump(const Duration(seconds: 16));
        }
        await tester.pumpAndSettle();
        conferirErro(tester);
        expect(find.byType(ConversaDetalheTela), findsOneWidget);
        expect(find.byType(DetalhesCaronaTela), findsNothing);
        expect(find.byType(TextField), findsOneWidget);
        expect(consultas, 1);
        if (situacao == 'timeout') {
          pendente.complete({'sucesso': false});
          await tester.pumpAndSettle();
          expect(consultas, 1);
        }
      }),
    );
  }

  for (final remover in [false, true]) {
    testWidgets(
      'falha tardia do chat nao mostra aviso em outra tela remover=$remover',
      (tester) => executar(tester, () async {
        final navegador = GlobalKey<NavigatorState>();
        final pendente = Completer<Map<String, dynamic>>();
        await abrirChat(tester, (_) => pendente.future, navegador: navegador);
        await tester.tap(
          find.byKey(const ValueKey('cabecalho-detalhes-carona')),
        );
        await tester.pump();
        await cobrirOuRemover(tester, navegador, remover);
        pendente.complete({'sucesso': false, 'mensagem': 'Falha atrasada'});
        await tester.pumpAndSettle();
        conferirOutraTela(tester);
      }),
    );
  }

  testWidgets(
    'erro inicial de notificacoes permanece na tela sem popup',
    (tester) => executar(tester, () async {
      final service = CentralControlada()..falha = true;
      await tester.pumpWidget(
        MaterialApp(home: NotificacoesTela(service: service)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Falha sintetica'), findsOneWidget);
      expect(find.text('Tentar novamente'), findsOneWidget);
      expect(find.byType(AvisoApp), findsNothing);
      service.falha = false;
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(find.text('CNH conferida'), findsOneWidget);
      expect(service.aberturas, 2);
    }),
  );

  for (final excecao in [false, true]) {
    testWidgets(
      'falha no refresh preserva itens e leitura excecao=$excecao',
      (tester) => executar(tester, () async {
        var leituras = 0;
        final service = CentralControlada();
        await tester.pumpWidget(
          MaterialApp(
            home: NotificacoesTela(
              service: service,
              onLeituraConfirmada: (_) => leituras++,
            ),
          ),
        );
        await tester.pumpAndSettle();
        service.consulta = () async {
          if (excecao) throw StateError('Falha sintetica');
          return {'sucesso': false, 'mensagem': 'Atualizacao indisponivel'};
        };
        await tester.drag(find.byType(ListView), const Offset(0, 400));
        await tester.pumpAndSettle();
        conferirErro(tester);
        expect(find.text('CNH conferida'), findsOneWidget);
        expect(leituras, 1);
        expect(service.aberturas, 1);
        expect(service.consultas, 1);
      }),
    );
  }

  testWidgets(
    'falha de paginacao preserva historico e permite repetir',
    (tester) => executar(tester, () async {
      final service = CentralControlada()
        ..primeira = PaginaNotificacoes(
          itens: [notificacoes.aviso(8)],
          totalNaoLidas: 0,
          temMais: true,
          proximoAntesDe: 8,
        );
      await tester.pumpWidget(
        MaterialApp(home: NotificacoesTela(service: service)),
      );
      await tester.pumpAndSettle();
      service.consulta = () async => {
        'sucesso': false,
        'mensagem': 'Pagina indisponivel',
      };
      await tester.tap(find.text('Carregar anteriores'));
      await tester.pumpAndSettle();
      conferirErro(tester);
      expect(find.text('CNH conferida'), findsOneWidget);
      expect(find.text('Carregar anteriores'), findsOneWidget);
      service.consulta = () async => {
        'sucesso': true,
        'dados': service.anterior,
      };
      await tester.tap(find.text('Carregar anteriores'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('notificacao_7')), findsOneWidget);
      expect(service.aberturas, 1);
      expect(service.consultas, 2);
    }),
  );

  testWidgets(
    'falha ao abrir notificacao fica vermelha e libera nova tentativa',
    (tester) => executar(tester, () async {
      final service = CentralControlada();
      var tentativas = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: NotificacoesTela(
            service: service,
            abrirRelacionada: (_) async {
              tentativas++;
              if (tentativas == 1) throw StateError('Indisponivel');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('notificacao_8')));
      await tester.pumpAndSettle();
      conferirErro(tester);
      expect(
        find.text('Não foi possível abrir esta atualização. Tente novamente'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('notificacao_8')));
      await tester.pumpAndSettle();
      expect(tentativas, 2);
      expect(service.aberturas, 1);
    }),
  );

  for (final remover in [false, true]) {
    for (final abertura in [false, true]) {
      testWidgets(
        'erro tardio notificacoes abertura=$abertura remover=$remover',
        (tester) => executar(tester, () async {
          final navegador = GlobalKey<NavigatorState>();
          final pendente = Completer<void>();
          final service = CentralControlada();
          await tester.pumpWidget(
            MaterialApp(
              navigatorKey: navegador,
              home: NotificacoesTela(
                service: service,
                abrirRelacionada: (_) async {
                  await pendente.future;
                  throw StateError('Falha atrasada');
                },
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (abertura) {
            await tester.tap(find.byKey(const ValueKey('notificacao_8')));
          } else {
            service.consulta = () async {
              await pendente.future;
              return {'sucesso': false, 'mensagem': 'Consulta atrasada'};
            };
            final dynamic estado = tester.state(find.byType(NotificacoesTela));
            estado.atualizar();
          }
          await tester.pump();
          await cobrirOuRemover(tester, navegador, remover);
          pendente.complete();
          await tester.pumpAndSettle();
          conferirOutraTela(tester);
        }),
      );
    }
  }
}
