import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: implementation_imports
import 'package:flutter_test/src/_binding_io.dart' as test_io;
import 'package:integration_test/integration_test.dart';
import 'package:uni_carona/config/app_theme.dart';
import 'package:uni_carona/home/conversa_detalhe.dart';
import 'package:uni_carona/models/mensagem.dart';
import '../test/detalhes_carona_test.dart' as detalhes;
import '../test/perfil_test.dart' as perfil;
import '../test/buscar_carona_visual_test.dart' as busca;
import '../test/login_visual_test.dart' as login;
import '../test/cadastro_test.dart' as cadastro;
import '../test/recuperacao_visual_protecoes_test.dart' as recuperacao;
import '../test/recortar_cnh_test.dart' as recorte;
import '../test/mapa_navegacao_carona_test.dart' as mapaMotorista;
import '../test/mapa_acompanhamento_passageiro_test.dart' as mapaPassageiro;
import '../test/mapa_encontro_sem_gps_test.dart' as encontro;
import '../test/proximas_telas_visual_test.dart' as modelos;

void main() {
  final binding=IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  test_io.setupHttpOverrides();
  setUp(()=>binding.testTextInput.register());
  tearDown(()=>binding.testTextInput.unregister());
  group('Reproducao detalhes com mock nativo',detalhes.main);
  group('Reproducao perfil com rolagem visivel',perfil.main);
  group('Reproducao busca com mock nativo',busca.main);
  group('Login no aparelho',login.main);
  group('Cadastro no aparelho',cadastro.main);
  group('Recuperacao no aparelho',recuperacao.main);
  group('Recorte CNH no aparelho',recorte.main);
  group('Mapa motorista no aparelho',mapaMotorista.main);
  group('Mapa passageiro no aparelho',mapaPassageiro.main);
  group('Encontro sem GPS',encontro.main);

  for (final encerrada in [false,true]) {
    testWidgets('REPRO: chat carrega sem overflow em tela pequena encerrada=$encerrada',(tester) async {
      await binding.setSurfaceSize(Size(320,encerrada?560:700));
      addTearDown(()=>binding.setSurfaceSize(null));
      modelos.textosLongos=true;
      final pending=Completer<Map<String,dynamic>>();
      await tester.pumpWidget(MaterialApp(
        theme:AppTheme.lightTheme,
        builder:(context,child)=>MediaQuery(data:MediaQuery.of(context).copyWith(textScaler:TextScaler.linear(encerrada?1.8:1.5),viewInsets:EdgeInsets.only(bottom:encerrada?0:300)),child:child!),
        home:ConversaDetalheTela(conversa:modelos.conversa(3,'Pessoa de teste','Mensagem',encerrada:encerrada),idUsuario:1,usarRealtime:false,carregarMensagens:()=>pending.future),
      ));
      await tester.pump(const Duration(milliseconds:150));
      final exception=tester.takeException();
      pending.complete({'sucesso':true,'dados':<Mensagem>[]});
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(exception,isNull,reason:'O estado de carregamento tambem precisa caber antes da resposta');
    });
  }
}
