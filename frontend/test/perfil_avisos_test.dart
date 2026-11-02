import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uni_carona/config/app_colors.dart';
import 'package:uni_carona/config/app_theme.dart';
import 'package:uni_carona/home/perfil.dart';
import 'package:uni_carona/models/instituicao.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/widgets/aviso_app.dart';
import 'package:uni_carona/widgets/conteudo_perfil_buscaeu.dart';
import 'package:uni_carona/widgets/dialogo_veiculo.dart';

const usuario = {
  'id': 1,
  'nome': 'Usuario de teste',
  'email': 'usuario@example.test',
  'idInstituicao': 1,
  'instituicao': 'UniSalesiano',
  'campus': 'Aracatuba',
  'tipoPerfil': 'PASSAGEIRO',
  'veiculo': {
    'id': 1,
    'modelo': 'Honda Civic',
    'cor': 'Branco',
    'placa': 'ABC1D23',
  },
};
final perfilAtualizado = {
  ...usuario,
  'idInstituicao': 2,
  'instituicao': 'Fatec',
  'campus': 'Centro',
};

Future<void> abrir(
  WidgetTester tester, {
  AtualizarPerfil? atualizar,
  SelecionarFotoPerfil? selecionar,
  EnviarFotoPerfil? enviarFoto,
  SalvarVeiculo? salvarVeiculo,
  GlobalKey<NavigatorState>? navigator,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigator,
      theme: AppTheme.lightTheme,
      home: PerfilTela(
        carregarPerfil: () async => {'sucesso': true, 'dados': usuario},
        carregarAvaliacoes: (_, _) async => {
          'sucesso': true,
          'dados': {'media': 0, 'total': 0},
        },
        buscarInstituicoes: (_) async => const [
          Instituicao(
            id: 2,
            nome: 'Fatec',
            sigla: null,
            campus: 'Centro',
            municipio: 'Aracatuba',
            uf: 'SP',
          ),
        ],
        atualizarPerfil: atualizar ?? (_, _) async => {'sucesso': false},
        selecionarFoto: selecionar ?? () async => null,
        enviarFoto: enviarFoto ?? (_) async => {'sucesso': false},
        salvarVeiculo: salvarVeiculo ?? (_, _, _) async => {'sucesso': false},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tocar(
  WidgetTester tester,
  Finder alvo, {
  bool aguardar = true,
}) async {
  await tester.ensureVisible(alvo);
  await tester.pumpAndSettle();
  await tester.tap(alvo);
  await tester.pump();
  if (aguardar) await tester.pumpAndSettle();
}

Future<void> editar(WidgetTester tester, {bool aguardar = true}) async {
  await tocar(tester, find.byTooltip('Editar perfil'));
  await tester.enterText(find.byType(TextField), 'Fatec');
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
  await tocar(tester, find.widgetWithText(ListTile, 'Fatec'));
  await tocar(
    tester,
    find.widgetWithText(FilledButton, 'Salvar'),
    aguardar: aguardar,
  );
}

ConteudoPerfilBuscaEu dados(WidgetTester tester) =>
    tester.widget<ConteudoPerfilBuscaEu>(find.byType(ConteudoPerfilBuscaEu));

void conferirAviso(WidgetTester tester, String mensagem, TipoAviso tipo) {
  expect(find.text(mensagem), findsOneWidget);
  expect(tester.widget<AvisoApp>(find.byType(AvisoApp)).tipo, tipo);
  final aviso = tester.widget<SnackBar>(find.byType(SnackBar));
  expect(aviso.duration, Duration(seconds: tipo == TipoAviso.sucesso ? 2 : 5));
  expect(aviso.showCloseIcon, isFalse);
  final cartao = tester.widget<Material>(
    find
        .descendant(of: find.byType(AvisoApp), matching: find.byType(Material))
        .first,
  );
  expect(
    cartao.color,
    tipo == TipoAviso.sucesso
        ? const Color(0xFF15803D)
        : const Color(0xFFC62828),
  );
  expect(tester.widget<Text>(find.text(mensagem)).style!.color, Colors.white);
  expect(
    tester
        .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
        .selectedItemColor,
    AppColors.primary,
  );
  expect(tester.takeException(), isNull);
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    AuthService.tokenUsuarioLogado = null;
    AuthService.usuarioLogado = null;
  });
  tearDown(() {
    AuthService.tokenUsuarioLogado = null;
    AuthService.usuarioLogado = null;
  });

  for (final temMensagem in [false, true]) {
    testWidgets('perfil salvo tem aviso verde com mensagem=$temMensagem', (
      tester,
    ) async {
      var chamadas = 0;
      await abrir(
        tester,
        atualizar: (id, campus) async {
          chamadas++;
          expect(id, 2);
          expect(campus, 'Centro');
          return {
            'sucesso': true,
            'dados': perfilAtualizado,
            if (temMensagem) 'mensagem': 'Dados atualizados',
          };
        },
      );
      await editar(tester);
      expect(chamadas, 1);
      conferirAviso(
        tester,
        temMensagem ? 'Dados atualizados' : 'Perfil atualizado com sucesso',
        TipoAviso.sucesso,
      );
      expect(dados(tester).usuario, perfilAtualizado);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.byType(AvisoApp), findsNothing);
    });

    testWidgets(
      'falha ao editar perfil tem aviso vermelho com mensagem=$temMensagem',
      (tester) async {
        await abrir(
          tester,
          atualizar: (_, _) async => {
            'sucesso': false,
            if (temMensagem) 'mensagem': 'Perfil indisponivel',
          },
        );
        await editar(tester);
        conferirAviso(
          tester,
          temMensagem ? 'Perfil indisponivel' : 'Erro ao atualizar perfil',
          TipoAviso.erro,
        );
        expect(dados(tester).usuario, usuario);
        expect(dados(tester).carregando, isFalse);
      },
    );

    testWidgets('foto salva tem aviso verde com mensagem=$temMensagem', (
      tester,
    ) async {
      String? caminho;
      await abrir(
        tester,
        selecionar: () async => XFile('foto-teste.jpg'),
        enviarFoto: (valor) async {
          caminho = valor;
          return {
            'sucesso': true,
            'dados': perfilAtualizado,
            if (temMensagem) 'mensagem': 'Foto salva',
          };
        },
      );
      await tocar(tester, find.byTooltip('Alterar foto de perfil'));
      expect(caminho, 'foto-teste.jpg');
      conferirAviso(
        tester,
        temMensagem ? 'Foto salva' : 'Foto atualizada com sucesso',
        TipoAviso.sucesso,
      );
      expect(dados(tester).usuario, perfilAtualizado);
      expect(dados(tester).enviandoFoto, isFalse);
    });

    testWidgets('falha de foto tem aviso vermelho com mensagem=$temMensagem', (
      tester,
    ) async {
      await abrir(
        tester,
        selecionar: () async => XFile('foto-teste.jpg'),
        enviarFoto: (_) async => {
          'sucesso': false,
          if (temMensagem) 'mensagem': 'Envio recusado',
        },
      );
      await tocar(tester, find.byTooltip('Alterar foto de perfil'));
      conferirAviso(
        tester,
        temMensagem ? 'Envio recusado' : 'Não foi possível atualizar a foto',
        TipoAviso.erro,
      );
      expect(dados(tester).usuario, usuario);
      expect(dados(tester).enviandoFoto, isFalse);
    });

    testWidgets('veiculo salvo tem aviso verde com mensagem=$temMensagem', (
      tester,
    ) async {
      var chamadas = 0;
      await abrir(
        tester,
        salvarVeiculo: (modelo, cor, placa) async {
          chamadas++;
          expect(modelo, 'Chevrolet Onix');
          expect(cor, 'Branco');
          expect(placa, 'ABC1D23');
          return {
            'sucesso': true,
            'dados': {'modelo': modelo, 'cor': cor, 'placa': placa},
            if (temMensagem) 'mensagem': 'Veiculo atualizado',
          };
        },
      );
      await tocar(tester, find.widgetWithText(ListTile, 'Honda Civic'));
      await tester.enterText(
        find.byKey(const Key('veiculo-modelo')),
        'Chevrolet Onix',
      );
      await tocar(tester, find.byKey(const Key('veiculo-salvar')));
      expect(chamadas, 1);
      expect(find.byType(DialogoVeiculo), findsNothing);
      conferirAviso(
        tester,
        temMensagem ? 'Veiculo atualizado' : 'Veículo salvo com sucesso',
        TipoAviso.sucesso,
      );
      expect(
        (dados(tester).usuario['veiculo'] as Map)['modelo'],
        'Chevrolet Onix',
      );
    });
  }

  testWidgets('cancelar a galeria nao envia foto nem mostra aviso', (
    tester,
  ) async {
    var envios = 0;
    await abrir(
      tester,
      selecionar: () async => null,
      enviarFoto: (_) async {
        envios++;
        return {'sucesso': true};
      },
    );
    await tocar(tester, find.byTooltip('Alterar foto de perfil'));
    expect(envios, 0);
    expect(find.byType(AvisoApp), findsNothing);
    expect(dados(tester).enviandoFoto, isFalse);
  });

  for (final origem in ['galeria', 'envio']) {
    testWidgets('excecao na foto identifica falha de $origem', (tester) async {
      await abrir(
        tester,
        selecionar: () async {
          if (origem == 'galeria') throw StateError('Falha simulada');
          return XFile('foto-teste.jpg');
        },
        enviarFoto: (_) async => throw StateError('Falha simulada'),
      );
      await tocar(tester, find.byTooltip('Alterar foto de perfil'));
      conferirAviso(
        tester,
        origem == 'galeria'
            ? 'Não foi possível selecionar a foto'
            : 'Não foi possível atualizar a foto. Tente novamente',
        TipoAviso.erro,
      );
      expect(dados(tester).usuario, usuario);
      expect(dados(tester).enviandoFoto, isFalse);
    });
  }

  for (final alvo in ['perfil', 'veiculo']) {
    testWidgets('cancelar edicao de $alvo nao salva nem mostra aviso', (
      tester,
    ) async {
      var chamadas = 0;
      await abrir(
        tester,
        atualizar: (_, _) async {
          chamadas++;
          return {'sucesso': false};
        },
        salvarVeiculo: (_, _, _) async {
          chamadas++;
          return {'sucesso': false};
        },
      );
      await tocar(
        tester,
        alvo == 'perfil'
            ? find.byTooltip('Editar perfil')
            : find.widgetWithText(ListTile, 'Honda Civic'),
      );
      await tocar(tester, find.text('Cancelar'));
      expect(chamadas, 0);
      expect(find.byType(AvisoApp), findsNothing);
      expect(dados(tester).usuario, usuario);
    });
  }

  testWidgets(
    'erro de veiculo permanece no formulario e sucesso posterior fica verde',
    (tester) async {
      var chamadas = 0;
      await abrir(
        tester,
        salvarVeiculo: (modelo, cor, placa) async {
          chamadas++;
          if (chamadas == 1) {
            return {'sucesso': false, 'mensagem': 'Veiculo indisponivel'};
          }
          return {
            'sucesso': true,
            'dados': {'modelo': modelo, 'cor': cor, 'placa': placa},
          };
        },
      );
      await tocar(tester, find.widgetWithText(ListTile, 'Honda Civic'));
      await tester.enterText(
        find.byKey(const Key('veiculo-modelo')),
        'Chevrolet Onix',
      );
      await tocar(tester, find.byKey(const Key('veiculo-salvar')));
      expect(find.byType(DialogoVeiculo), findsOneWidget);
      expect(find.text('Veiculo indisponivel'), findsOneWidget);
      expect(find.byType(AvisoApp), findsNothing);
      expect(dados(tester).usuario, usuario);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('veiculo-modelo')))
            .controller!
            .text,
        'Chevrolet Onix',
      );
      await tocar(tester, find.byKey(const Key('veiculo-salvar')));
      expect(chamadas, 2);
      conferirAviso(tester, 'Veículo salvo com sucesso', TipoAviso.sucesso);
    },
  );

  for (final operacao in ['perfil', 'foto']) {
    for (final remover in [false, true]) {
      for (final sucesso in [false, true]) {
        testWidgets(
          '$operacao nao avisa apos tela ${remover ? 'removida' : 'coberta'}, sucesso=$sucesso',
          (tester) async {
            final navigator = GlobalKey<NavigatorState>();
            final pendente = Completer<Map<String, dynamic>>();
            await abrir(
              tester,
              navigator: navigator,
              atualizar: (_, _) => pendente.future,
              selecionar: () async => XFile('foto-teste.jpg'),
              enviarFoto: (_) => pendente.future,
            );
            if (operacao == 'perfil') {
              await editar(tester, aguardar: false);
            } else {
              await tocar(
                tester,
                find.byTooltip('Alterar foto de perfil'),
                aguardar: false,
              );
            }
            final outra = MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Outra tela')),
            );
            if (remover) {
              navigator.currentState!.pushReplacement(outra);
            } else {
              navigator.currentState!.push(outra);
            }
            await tester.pumpAndSettle();
            pendente.complete({
              'sucesso': sucesso,
              'dados': perfilAtualizado,
              'mensagem': 'Resposta tardia',
            });
            await tester.pumpAndSettle();
            expect(find.text('Outra tela'), findsOneWidget);
            expect(find.byType(AvisoApp), findsNothing);
            expect(find.byType(SnackBar), findsNothing);
            expect(tester.takeException(), isNull);
            if (!remover) {
              navigator.currentState!.pop();
              await tester.pumpAndSettle();
              expect(
                dados(tester).usuario,
                sucesso ? perfilAtualizado : usuario,
              );
              expect(find.byType(AvisoApp), findsNothing);
            }
          },
        );
      }
    }
  }
}
