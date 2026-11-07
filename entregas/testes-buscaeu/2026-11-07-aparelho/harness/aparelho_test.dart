import 'dart:io';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: implementation_imports
import 'package:flutter_test/src/_binding_io.dart' as test_io;
import 'package:geolocator/geolocator.dart';
import 'package:integration_test/integration_test.dart';
import 'package:uni_carona/services/ocr_cnh_service.dart';
import '../test/widget_test.dart' as login;
import '../test/app_inicializacao_test.dart' as abertura;
import '../test/cancelamento_estorno_simulado_test.dart' as estorno;
import '../test/detalhes_carona_test.dart' as detalhes;
import '../test/minhas_caronas_test.dart' as caronas;
import '../test/perfil_test.dart' as perfil;
import '../test/proximas_telas_visual_test.dart' as telas;
import '../test/recorrencias_test.dart' as recorrencias;
import '../test/verificacao_cnh_test.dart' as cnh;
import '../test/notificacoes_test.dart' as notificacoes;
import '../test/conversa_detalhe_test.dart' as chat;
import '../test/pagamento_pix_test.dart' as pix;
import '../test/selecionar_destino_visual_test.dart' as destino;
import '../test/buscar_carona_visual_test.dart' as busca;
import '../test/ofertar_carona_cnh_test.dart' as oferta;

Future<Uint8List> documentoSintetico(int giros) async {
  const largura = 1600, altura = 1000;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawColor(Colors.white, BlendMode.src);
  final lines = <(String,double,double)>[
    ('DOCUMENTO SINTETICO PARA TESTES - SEM VALIDADE', 40, 25),
    ('2 e 1 NOME E SOBRENOME', 70, 145),
    ('PESSOA FICTICIA DE TESTE', 70, 205),
    ('4d CPF', 70, 365),
    ('000.000.000-00', 70, 425),
    ('4b VALIDADE', 760, 365),
    ('31/12/2099', 760, 425),
    ('5 No REGISTRO', 70, 620),
    ('00000000000', 70, 680),
    ('9 CAT HAB', 900, 620),
    ('AB', 900, 680),
  ];
  for (final line in lines) {
    final painter = TextPainter(
      text: TextSpan(text: line.$1, style: const TextStyle(fontSize: 38, color: Colors.black)),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(line.$2,line.$3));
    painter.dispose();
  }
  final picture = recorder.endRecording();
  final original = await picture.toImage(largura, altura);
  picture.dispose();
  final rotation = ui.PictureRecorder();
  final rotatedCanvas = Canvas(rotation);
  final w = giros.isEven ? largura : altura;
  final h = giros.isEven ? altura : largura;
  if (giros == 1) rotatedCanvas.translate(w.toDouble(), 0);
  if (giros == 2) rotatedCanvas.translate(w.toDouble(), h.toDouble());
  if (giros == 3) rotatedCanvas.translate(0, h.toDouble());
  rotatedCanvas.rotate(giros * 3.141592653589793 / 2);
  rotatedCanvas.drawImage(original, Offset.zero, Paint());
  final drawing = rotation.endRecording();
  final image = await drawing.toImage(w, h);
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  image.dispose(); drawing.dispose(); original.dispose();
  return bytes;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  test_io.setupHttpOverrides();
  setUp(() => binding.testTextInput.register());
  tearDown(() => binding.testTextInput.unregister());
  testWidgets('NATIVO: resolucao real e renderizacao do Android', (tester) async {
    final view = binding.platformDispatcher.views.first;
    expect(view.physicalSize.width, greaterThan(0));
    expect(view.physicalSize.height, greaterThan(0));
    binding.reportData = {'dispositivo': {'largura': view.physicalSize.width, 'altura': view.physicalSize.height, 'densidade': view.devicePixelRatio}, 'backend': 'simulado; sem mutacoes remotas'};
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('BuscaEu testes no Android'))));
    await tester.pumpAndSettle();
    expect(find.text('BuscaEu testes no Android'), findsOneWidget);
  });
  for (final turns in [0,1,2,3]) {
    testWidgets('NATIVO: ML Kit reconhece documento sintetico em ${turns * 90} graus', (tester) async {
      final bytes = await documentoSintetico(turns);
      final result = await lerCnhNoCelular(bytes).timeout(const Duration(seconds: 60));
      final words = (result['linhas'] as List).expand((line) => line['palavras'] as List).map((word) => word['texto'].toString().toUpperCase()).join(' ');
      expect(words, contains('PESSOA'));
      expect(words, contains('FICTICIA'));
      expect(words, contains('2099'));
      expect(result['largura'], 1600);
      expect(result['altura'], 1000);
      bytes.fillRange(0,bytes.length,0);
      final remaining = Directory.systemTemp.listSync().whereType<Directory>().where((d) => d.path.split('/').last.startsWith('buscaeu_cnh_'));
      expect(remaining, isEmpty, reason: 'OCR deve descartar arquivo temporario');
    }, timeout: const Timeout(Duration(minutes: 2)));
  }
  testWidgets('NATIVO: camera traseira inicializa e libera sem fotografar', (tester) async {
    final cameras = await availableCameras();
    expect(cameras.where((c) => c.lensDirection == CameraLensDirection.back), isNotEmpty);
    final camera = CameraController(cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back),ResolutionPreset.veryHigh,enableAudio:false);
    try {
      await camera.initialize().timeout(const Duration(seconds: 30));
      expect(camera.value.isInitialized, isTrue);
      await camera.lockCaptureOrientation(DeviceOrientation.landscapeLeft);
    } finally { await camera.dispose(); }
  });
  testWidgets('NATIVO: localizacao responde sem registrar coordenadas', (tester) async {
    expect(await Geolocator.isLocationServiceEnabled(), isTrue);
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    expect(permission, isIn([LocationPermission.whileInUse,LocationPermission.always]));
    final position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high,timeLimit:Duration(seconds:30)));
    expect(position.latitude.isFinite && position.longitude.isFinite, isTrue);
    expect(position.accuracy, greaterThanOrEqualTo(0));
  });
  group('Login', login.main);
  group('Inicializacao', abertura.main);
  group('Cancelamento e estorno', estorno.main);
  group('Detalhes de carona', detalhes.main);
  group('Solicitacoes', caronas.main);
  group('Perfil e veiculo', perfil.main);
  group('Conversas historico avaliacoes e recorrencias visual', telas.main);
  group('Recorrencias', recorrencias.main);
  group('CNH interface e privacidade', cnh.main);
  group('Notificacoes', notificacoes.main);
  group('Chat', chat.main);
  group('Pix simulado interface', pix.main);
  group('Escolher destino', destino.main);
  group('Busca', busca.main);
  group('Ofertar exige CNH', oferta.main);
}
