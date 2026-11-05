import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uni_carona/home/perfil.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/services/memoria_resumo_perfil.dart';
import 'package:uni_carona/services/mensagem_service.dart';
import 'package:uni_carona/services/solicitacao_service.dart';
import 'package:uni_carona/widgets/conteudo_perfil_buscaeu.dart';

import 'perfil_avisos_test.dart' show usuario;

Map<String, dynamic> perfilOk([Map<String, dynamic>? dados]) => {
  'sucesso': true,
  'dados': dados ?? usuario,
};

Map<String, dynamic> avaliacoesOk({double media = 4.5, int total = 2}) => {
  'sucesso': true,
  'dados': {
    'media': media,
    'total': total,
    'pagina': 1,
    'totalPaginas': 1,
    'avaliacoes': [],
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MemoriaResumoPerfil memoria;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    AuthService.tokenUsuarioLogado = null;
    AuthService.usuarioLogado = null;
    memoria = MemoriaResumoPerfil();
  });
  tearDown(() async {
    SolicitacaoService.pararContadorSolicitacoesPendentes();
    await MensagemService.pararContadorMensagensNaoLidas();
    AuthService.tokenUsuarioLogado = null;
    AuthService.usuarioLogado = null;
  });

  Widget tela({
    CarregarPerfil? carregar,
    Future<Map<String, dynamic>> Function(int, int)? avaliacoes,
    SelecionarFotoPerfil? camera,
    EnviarFotoPerfil? enviar,
    AtualizarPerfil? atualizar,
    SalvarVeiculo? salvarVeiculo,
    GlobalKey<NavigatorState>? navegador,
  }) => MaterialApp(
    navigatorKey: navegador,
    home: PerfilTela(
      memoriaResumo: memoria,
      carregarPerfil: carregar ?? () async => perfilOk(),
      carregarAvaliacoes: avaliacoes ?? (_, _) async => avaliacoesOk(),
      capturarFoto: camera,
      enviarFoto: enviar,
      atualizarPerfil: atualizar,
      salvarVeiculo: salvarVeiculo,
    ),
  );

  ConteudoPerfilBuscaEu conteudo(WidgetTester tester) =>
      tester.widget(find.byType(ConteudoPerfilBuscaEu));

  Future<void> limpar(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    SolicitacaoService.pararContadorSolicitacoesPendentes();
    await MensagemService.pararContadorMensagensNaoLidas();
  }

  testWidgets('sem sessao nao consulta nem permanece carregando', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: PerfilTela()));
    await tester.pumpAndSettle();
    expect(conteudo(tester).carregando, isFalse);
    expect(conteudo(tester).acoesHabilitadas, isFalse);
    expect(conteudo(tester).usuario, isEmpty);
    expect(find.textContaining('Sua sessão mudou'), findsOneWidget);
    await limpar(tester);
  });

  testWidgets(
    'botao de instituicao aguarda confirmacao do perfil sem depender das notas',
    (tester) async {
      AuthService.usuarioLogado = Map<String, dynamic>.from(usuario);
      final pendente = Completer<Map<String, dynamic>>();
      final notas = Completer<Map<String, dynamic>>();
      await tester.pumpWidget(
        tela(
          carregar: () => pendente.future,
          avaliacoes: (_, _) => notas.future,
        ),
      );
      await tester.pump();
      final botao = find.byKey(const ValueKey('alterar-instituicao'));
      await tester.scrollUntilVisible(
        botao,
        200,
        scrollable: find
            .descendant(
              of: find.byType(ConteudoPerfilBuscaEu),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(tester.widget<OutlinedButton>(botao).onPressed, isNull);
      pendente.complete(perfilOk());
      await tester.pump();
      await tester.pump();
      expect(tester.widget<OutlinedButton>(botao).onPressed, isNotNull);
      expect(conteudo(tester).carregandoAvaliacoes, isTrue);
      notas.complete(avaliacoesOk());
      await tester.pumpAndSettle();
      await limpar(tester);
    },
  );

  testWidgets(
    'libera perfil antes de terminar avaliacoes sem inventar nota zero',
    (tester) async {
      final pendente = Completer<Map<String, dynamic>>();
      await tester.pumpWidget(tela(avaliacoes: (_, _) => pendente.future));
      await tester.pump();
      await tester.pump();
      expect(conteudo(tester).usuario, usuario);
      expect(conteudo(tester).carregando, isFalse);
      expect(conteudo(tester).atualizando, isFalse);
      expect(conteudo(tester).acoesHabilitadas, isTrue);
      expect(conteudo(tester).carregandoAvaliacoes, isTrue);
      expect(conteudo(tester).avaliacoesDisponiveis, isFalse);
      expect(find.text('0,0 / 5'), findsNothing);
      expect(find.text('Sem avaliações'), findsNothing);
      pendente.complete(avaliacoesOk());
      await tester.pumpAndSettle();
      expect(find.text('4,5 / 5'), findsOneWidget);
      await limpar(tester);
    },
  );

  testWidgets(
    'com conta conhecida inicia as consultas em paralelo e compartilha refresh',
    (tester) async {
      AuthService.usuarioLogado = Map<String, dynamic>.from(usuario);
      final perfil = Completer<Map<String, dynamic>>();
      final resumo = Completer<Map<String, dynamic>>();
      var perfis = 0;
      var notas = 0;
      await tester.pumpWidget(
        tela(
          carregar: () {
            perfis++;
            return perfil.future;
          },
          avaliacoes: (_, _) {
            notas++;
            return resumo.future;
          },
        ),
      );
      await tester.pump();
      expect(perfis, 1);
      expect(notas, 1);
      expect(conteudo(tester).usuario, usuario);
      expect(conteudo(tester).acoesHabilitadas, isFalse);
      final dynamic estado = tester.state(find.byType(PerfilTela));
      final Future<void> primeira = estado.carregarDados();
      final Future<void> segunda = estado.carregarDados();
      expect(perfis, 1);
      expect(notas, 1);
      perfil.complete(perfilOk());
      resumo.complete(avaliacoesOk());
      await tester.pumpAndSettle();
      await Future.wait([primeira, segunda]);
      expect(conteudo(tester).acoesHabilitadas, isTrue);
      await limpar(tester);
    },
  );

  testWidgets('reabre preservando perfil e resumo antes das respostas', (
    tester,
  ) async {
    AuthService.usuarioLogado = Map<String, dynamic>.from(usuario);
    await tester.pumpWidget(tela());
    await tester.pumpAndSettle();
    await limpar(tester);
    final perfil = Completer<Map<String, dynamic>>();
    final resumo = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(
      tela(carregar: () => perfil.future, avaliacoes: (_, _) => resumo.future),
    );
    await tester.pump();
    expect(conteudo(tester).usuario, usuario);
    expect(find.text('4,5 / 5'), findsOneWidget);
    expect(conteudo(tester).carregando, isFalse);
    expect(conteudo(tester).atualizando, isTrue);
    perfil.complete(perfilOk());
    resumo.complete(avaliacoesOk(media: 5));
    await tester.pumpAndSettle();
    expect(find.text('5,0 / 5'), findsOneWidget);
    await limpar(tester);
  });

  testWidgets('falha das notas preserva resumo e retry nao recarrega perfil', (
    tester,
  ) async {
    var perfis = 0;
    var notas = 0;
    await tester.pumpWidget(
      tela(
        carregar: () async {
          perfis++;
          return perfilOk();
        },
        avaliacoes: (_, _) async => ++notas == 2
            ? {'sucesso': false, 'mensagem': 'Notas indisponiveis'}
            : avaliacoesOk(
                media: notas == 3 ? 0 : 4.5,
                total: notas == 3 ? 0 : 2,
              ),
      ),
    );
    await tester.pumpAndSettle();
    final dynamic estado = tester.state(find.byType(PerfilTela));
    await estado.atualizarAvaliacoes();
    await tester.pumpAndSettle();
    expect(find.text('4,5 / 5'), findsOneWidget);
    expect(find.text('2 avaliações'), findsOneWidget);
    expect(find.text('Notas indisponiveis'), findsOneWidget);
    expect(conteudo(tester).acoesHabilitadas, isTrue);
    await tester.ensureVisible(find.text('Atualizar avaliações'));
    await tester.tap(find.text('Atualizar avaliações'));
    await tester.pumpAndSettle();
    expect(perfis, 1);
    expect(conteudo(tester).media, 0);
    expect(conteudo(tester).totalAvaliacoes, 0);
    await tester.scrollUntilVisible(
      find.text('0,0 / 5'),
      -150,
      scrollable: find
          .descendant(
            of: find.byType(ConteudoPerfilBuscaEu),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('0,0 / 5'), findsOneWidget);
    expect(find.text('Sem avaliações'), findsOneWidget);
    expect(find.text('Notas indisponiveis'), findsNothing);
    await limpar(tester);
  });

  testWidgets('falha inicial de resumo nao exibe zero como dado confirmado', (
    tester,
  ) async {
    await tester.pumpWidget(
      tela(
        avaliacoes: (_, _) async => {
          'sucesso': false,
          'mensagem': 'Falha de rede',
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(conteudo(tester).usuario, usuario);
    expect(conteudo(tester).avaliacoesDisponiveis, isFalse);
    expect(find.text('0,0 / 5'), findsNothing);
    expect(find.text('Sem avaliações'), findsNothing);
    expect(find.text('Avaliações indisponíveis'), findsOneWidget);
    await limpar(tester);
  });

  testWidgets(
    'falha do perfil preserva dados e retry libera edicao apos confirmar',
    (tester) async {
      AuthService.usuarioLogado = Map<String, dynamic>.from(usuario);
      var perfis = 0;
      await tester.pumpWidget(
        tela(
          carregar: () async => ++perfis == 1
              ? {'sucesso': false, 'mensagem': 'Perfil indisponivel'}
              : perfilOk(),
        ),
      );
      await tester.pumpAndSettle();
      expect(conteudo(tester).usuario, usuario);
      expect(conteudo(tester).acoesHabilitadas, isFalse);
      await tester.ensureVisible(find.text('Tentar atualizar novamente'));
      await tester.tap(find.text('Tentar atualizar novamente'));
      await tester.pumpAndSettle();
      expect(perfis, 2);
      expect(conteudo(tester).acoesHabilitadas, isTrue);
      expect(find.text('Perfil indisponivel'), findsNothing);
      await limpar(tester);
    },
  );

  testWidgets('avaliacao atrasada nao restaura a foto anterior', (
    tester,
  ) async {
    final notas = Completer<Map<String, dynamic>>();
    final novaFoto = {
      ...usuario,
      'fotoPerfil': 'https://example.test/nova.jpg',
    };
    await tester.pumpWidget(
      tela(
        avaliacoes: (_, _) => notas.future,
        camera: () async => XFile('camera.jpg'),
        enviar: (_) async => perfilOk(novaFoto),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byTooltip('Alterar foto de perfil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tirar foto'));
    await tester.pumpAndSettle();
    expect(conteudo(tester).usuario['fotoPerfil'], novaFoto['fotoPerfil']);
    notas.complete(avaliacoesOk());
    await tester.pumpAndSettle();
    expect(conteudo(tester).usuario['fotoPerfil'], novaFoto['fotoPerfil']);
    expect(find.text('4,5 / 5'), findsOneWidget);
    await limpar(tester);
  });

  testWidgets('consulta nao inicia durante camera aberta', (tester) async {
    var perfis = 0;
    final camera = Completer<XFile?>();
    await tester.pumpWidget(
      tela(
        carregar: () async {
          perfis++;
          return perfilOk();
        },
        camera: () => camera.future,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Alterar foto de perfil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tirar foto'));
    await tester.pumpAndSettle();
    final dynamic estado = tester.state(find.byType(PerfilTela));
    await estado.carregarDados();
    expect(perfis, 1);
    camera.complete(null);
    await tester.pumpAndSettle();
    await estado.carregarDados();
    await tester.pumpAndSettle();
    expect(perfis, 2);
    await limpar(tester);
  });

  testWidgets(
    'logout durante consultas impede restauracao por respostas antigas',
    (tester) async {
      AuthService.usuarioLogado = Map<String, dynamic>.from(usuario);
      final perfil = Completer<Map<String, dynamic>>();
      final resumo = Completer<Map<String, dynamic>>();
      await tester.pumpWidget(
        tela(
          carregar: () => perfil.future,
          avaliacoes: (_, _) => resumo.future,
        ),
      );
      await tester.pump();
      AuthService.tokenUsuarioLogado = null;
      await tester.pump();
      expect(conteudo(tester).usuario, isEmpty);
      perfil.complete(perfilOk());
      resumo.complete(avaliacoesOk());
      await tester.pumpAndSettle();
      expect(conteudo(tester).usuario, isEmpty);
      expect(conteudo(tester).avaliacoesDisponiveis, isFalse);
      expect(conteudo(tester).acoesHabilitadas, isFalse);
      await limpar(tester);
    },
  );

  testWidgets('logout e novo login da mesma conta nao envia foto antiga', (
    tester,
  ) async {
    AuthService.usuarioLogado = Map<String, dynamic>.from(usuario);
    final camera = Completer<XFile?>();
    var envios = 0;
    await tester.pumpWidget(
      tela(
        camera: () => camera.future,
        enviar: (_) async {
          envios++;
          return perfilOk();
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Alterar foto de perfil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tirar foto'));
    await tester.pumpAndSettle();
    AuthService.tokenUsuarioLogado = null;
    AuthService.usuarioLogado = Map<String, dynamic>.from(usuario);
    AuthService.tokenUsuarioLogado = 'novo-login';
    camera.complete(XFile('foto-antiga.jpg'));
    await tester.pumpAndSettle();
    expect(envios, 0);
    await limpar(tester);
  });

  testWidgets('dispose durante consultas nao atualiza widget descartado', (
    tester,
  ) async {
    AuthService.usuarioLogado = Map<String, dynamic>.from(usuario);
    final perfil = Completer<Map<String, dynamic>>();
    final resumo = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(
      tela(carregar: () => perfil.future, avaliacoes: (_, _) => resumo.future),
    );
    final dynamic estado = tester.state(find.byType(PerfilTela));
    await limpar(tester);
    await estado.carregarDados();
    perfil.complete(perfilOk());
    resumo.complete(avaliacoesOk());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('voltar de avaliacoes reconsulta resumo sem consultar perfil', (
    tester,
  ) async {
    var media = 4.5;
    var perfis = 0;
    final navegador = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      tela(
        navegador: navegador,
        carregar: () async {
          perfis++;
          return perfilOk();
        },
        avaliacoes: (_, _) async => avaliacoesOk(media: media),
      ),
    );
    await tester.pumpAndSettle();
    final dynamic estado = tester.state(find.byType(PerfilTela));
    final Future<void> navegacao = estado.abrirAvaliacoes();
    await tester.pumpAndSettle();
    media = 5;
    navegador.currentState!.pop();
    await tester.pumpAndSettle();
    await navegacao;
    expect(perfis, 1);
    expect(find.text('5,0 / 5'), findsOneWidget);
    await limpar(tester);
  });

  testWidgets(
    'excecao ao editar instituicao libera controles e preserva perfil',
    (tester) async {
      await tester.pumpWidget(
        tela(atualizar: (_, _) async => throw StateError('teste')),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('alterar-instituicao')),
        200,
        scrollable: find
            .descendant(
              of: find.byType(ConteudoPerfilBuscaEu),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('alterar-instituicao')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('alterar-instituicao')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
      await tester.pumpAndSettle();
      expect(conteudo(tester).usuario, usuario);
      expect(conteudo(tester).acoesHabilitadas, isTrue);
      expect(conteudo(tester).atualizando, isFalse);
      expect(
        find.textContaining('Não foi possível confirmar a atualização'),
        findsOneWidget,
      );
      await limpar(tester);
    },
  );

  testWidgets(
    'fluxo padrao reaproveita resumo sem manter outra copia do perfil',
    (tester) async {
      AuthService.usuarioLogado = Map<String, dynamic>.from(usuario);
      AuthService.tokenUsuarioLogado = 'token-teste';
      var perfis = 0;
      var notas = 0;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(const MaterialApp(home: PerfilTela()));
          await tester.pumpAndSettle();
          expect(perfis, 1);
          expect(notas, 1);
          await limpar(tester);
          final perfil = Completer<http.Response>();
          final resumo = Completer<http.Response>();
          await http.runWithClient(
            () async {
              await tester.pumpWidget(const MaterialApp(home: PerfilTela()));
              await tester.pump();
              expect(conteudo(tester).usuario, usuario);
              expect(find.text('4,5 / 5'), findsOneWidget);
              perfil.complete(http.Response(jsonEncode(perfilOk()), 200));
              resumo.complete(http.Response(jsonEncode(avaliacoesOk()), 200));
              await tester.pumpAndSettle();
              await limpar(tester);
            },
            () => MockClient(
              (request) => request.url.path == '/usuarios/perfil'
                  ? perfil.future
                  : request.url.path.endsWith('/avaliacoes')
                  ? resumo.future
                  : Future.value(http.Response('{"dados":[]}', 200)),
            ),
          );
        },
        () => MockClient((request) async {
          if (request.url.path == '/usuarios/perfil') {
            perfis++;
            return http.Response(jsonEncode(perfilOk()), 200);
          }
          if (request.url.path.endsWith('/avaliacoes')) {
            notas++;
            return http.Response(jsonEncode(avaliacoesOk()), 200);
          }
          return http.Response('{"dados":[]}', 200);
        }),
      );
    },
  );

  testWidgets('consulta nao concorre com salvamento do veiculo', (
    tester,
  ) async {
    var perfis = 0;
    final salvar = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(
      tela(
        carregar: () async {
          perfis++;
          return perfilOk();
        },
        salvarVeiculo: (_, _, _) => salvar.future,
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(ListTile, 'Honda Civic'));
    await tester.tap(find.widgetWithText(ListTile, 'Honda Civic'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('veiculo-modelo')),
      'Chevrolet Onix',
    );
    await tester.tap(find.byKey(const Key('veiculo-salvar')));
    await tester.pump();
    final dynamic estado = tester.state(find.byType(PerfilTela));
    await estado.carregarDados();
    expect(perfis, 1);
    salvar.complete({
      'sucesso': true,
      'dados': {
        'modelo': 'Chevrolet Onix',
        'cor': 'Branco',
        'placa': 'ABC1D23',
      },
    });
    await tester.pumpAndSettle();
    expect(conteudo(tester).usuario['veiculo']['modelo'], 'Chevrolet Onix');
    expect(conteudo(tester).acoesHabilitadas, isTrue);
    await limpar(tester);
  });

  testWidgets('avisos longos de falha cabem com fonte ampliada', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    AuthService.usuarioLogado = Map<String, dynamic>.from(usuario);
    await tester.pumpWidget(
      tela(
        carregar: () async => {
          'sucesso': false,
          'mensagem':
              'Não foi possível atualizar os dados do perfil. Confira a conexão e tente novamente.',
        },
        avaliacoes: (_, _) async => {
          'sucesso': false,
          'mensagem':
              'Não foi possível atualizar as avaliações. Confira a conexão e tente novamente.',
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(conteudo(tester).usuario, usuario);
    expect(tester.takeException(), isNull);
    await limpar(tester);
  });

  testWidgets(
    'salvar veiculo apos trocar sessao nao usa as credenciais novas',
    (tester) async {
      var salvamentos = 0;
      await tester.pumpWidget(
        tela(
          salvarVeiculo: (_, _, _) async {
            salvamentos++;
            return {'sucesso': true, 'dados': usuario['veiculo']};
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(ListTile, 'Honda Civic'));
      await tester.tap(find.widgetWithText(ListTile, 'Honda Civic'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('veiculo-modelo')),
        'Chevrolet Onix',
      );
      AuthService.tokenUsuarioLogado = null;
      AuthService.usuarioLogado = {'id': 99};
      AuthService.tokenUsuarioLogado = 'outra-sessao';
      await tester.tap(find.byKey(const Key('veiculo-salvar')));
      await tester.pumpAndSettle();
      expect(salvamentos, 0);
      expect(find.text('Sua sessão mudou. Entre novamente.'), findsOneWidget);
      await limpar(tester);
    },
  );
}
