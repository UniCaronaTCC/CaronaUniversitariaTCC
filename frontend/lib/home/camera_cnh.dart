import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/recorte_guiado_cnh.dart';
import '../services/foto_cnh_temporaria.dart'
    if (dart.library.io) '../services/foto_cnh_temporaria_io.dart';
import '../widgets/moldura_camera_cnh.dart';

Future<Uint8List?> fotografarCnhGuiada(
  BuildContext context,
  String lado,
) async {
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
  ]);
  try {
    if (!context.mounted) return null;
    return await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(builder: (_) => CameraCnhTela(lado: lado)),
    );
  } finally {
    await SystemChrome.setPreferredOrientations([]);
  }
}

class CameraCnhTela extends StatefulWidget {
  final String lado;
  const CameraCnhTela({super.key, required this.lado});
  @override
  State<CameraCnhTela> createState() => _CameraCnhTelaState();
}

class _CameraCnhTelaState extends State<CameraCnhTela>
    with WidgetsBindingObserver {
  CameraController? camera;
  Uint8List? foto;
  String? erro;
  bool iniciando = false, capturando = false, ativa = true;
  int geracao = 0;
  Future<void> liberando = Future.value();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    iniciar();
  }

  Future<void> iniciar() async {
    if (iniciando || !ativa || camera != null || foto != null) return;
    final atual = ++geracao;
    setState(() {
      iniciando = true;
      erro = null;
    });
    CameraController? nova;
    try {
      await liberando;
      final cameras = await availableCameras();
      final traseiras = cameras.where(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      if (traseiras.isEmpty) throw CameraException('SemCamera', '');
      nova = CameraController(
        traseiras.first,
        ResolutionPreset.veryHigh,
        enableAudio: false,
      );
      await nova.initialize();
      await nova.lockCaptureOrientation(DeviceOrientation.landscapeLeft);
      try {
        await nova.setFlashMode(FlashMode.off);
      } on CameraException {
        /* Alguns dispositivos não têm flash. */
      }
      if (!mounted || !ativa || atual != geracao) return;
      setState(() => camera = nova);
      nova = null;
    } on CameraException catch (e) {
      if (mounted && atual == geracao) {
        setState(
          () => erro = e.code.startsWith('CameraAccess')
              ? 'Permita o acesso à câmera nas configurações do celular. Você também pode usar a galeria.'
              : 'Não foi possível abrir a câmera. Volte e use a galeria ou tente novamente.',
        );
      }
    } catch (_) {
      if (mounted && atual == geracao) {
        setState(() => erro = 'Não foi possível abrir a câmera.');
      }
    } finally {
      await nova?.dispose();
      if (mounted) {
        setState(() => iniciando = false);
        if (ativa && atual != geracao) unawaited(iniciar());
      }
    }
  }

  void liberar() {
    geracao++;
    final anterior = camera;
    camera = null;
    liberando = liberando.then((_) async {
      await anterior?.dispose();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ativa = true;
      unawaited(iniciar());
    } else {
      ativa = false;
      liberar();
      if (mounted) setState(() {});
    }
  }

  Future<void> capturar(Rect moldura, double proporcao) async {
    final atual = camera;
    if (atual == null || capturando || !ativa) return;
    setState(() {
      capturando = true;
      erro = null;
    });
    Uint8List? original;
    try {
      final arquivo = await atual.takePicture();
      try {
        original = await arquivo.readAsBytes();
      } finally {
        await descartarFotoCnh(arquivo.path);
      }
      final resultado = await recortarFotoGuiada(original, proporcao, moldura);
      if (!mounted || !ativa || camera != atual) {
        resultado.fillRange(0, resultado.length, 0);
        return;
      }
      setState(() => foto = resultado);
      liberar();
    } on FormatException catch (e) {
      if (mounted) setState(() => erro = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => erro = 'Não foi possível fotografar. Tente novamente.');
      }
    } finally {
      original?.fillRange(0, original.length, 0);
      if (mounted) setState(() => capturando = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    liberar();
    foto?.fillRange(0, foto!.length, 0);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final atual = camera;
    return PopScope(
      canPop: !capturando,
      child: Scaffold(
        appBar: AppBar(title: Text(widget.lado)),
        body: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: foto != null
                    ? Image.memory(foto!, fit: BoxFit.contain)
                    : atual == null
                    ? Center(
                        child: iniciando
                            ? const CircularProgressIndicator()
                            : const Icon(Icons.camera_alt_outlined),
                      )
                    : LayoutBuilder(
                        builder: (context, limites) {
                          final proporcao = atual.value.aspectRatio;
                          final tamanho = applyBoxFit(
                            BoxFit.contain,
                            Size(proporcao, 1),
                            limites.biggest,
                          ).destination;
                          final moldura = molduraCnh(tamanho);
                          return Center(
                            child: SizedBox(
                              width: tamanho.width,
                              height: tamanho.height,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CameraPreview(atual),
                                  MolduraCameraCnh(area: moldura),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              SizedBox(
                width: 190,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Text(
                        foto == null
                            ? 'Encaixe a CNH inteira na moldura, com as letras em pé. Apoie o documento e evite reflexos.'
                            : 'Confira se todos os campos estão inteiros e legíveis.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      if (erro != null)
                        Text(erro!, style: const TextStyle(color: Colors.red)),
                      if (foto == null)
                        FilledButton.icon(
                          onPressed: atual == null || capturando
                              ? null
                              : () => capturar(
                                  molduraCnh(Size(atual.value.aspectRatio, 1)),
                                  atual.value.aspectRatio,
                                ),
                          icon: const Icon(Icons.camera_alt),
                          label: Text(capturando ? 'Aguarde...' : 'Fotografar'),
                        )
                      else ...[
                        FilledButton(
                          onPressed: () {
                            final resultado = foto;
                            foto = null;
                            Navigator.pop(context, resultado);
                          },
                          child: const Text('Usar foto'),
                        ),
                        TextButton(
                          onPressed: () {
                            foto?.fillRange(0, foto!.length, 0);
                            setState(() {
                              foto = null;
                              erro = null;
                            });
                            iniciar();
                          },
                          child: const Text('Refazer'),
                        ),
                      ],
                      if (erro != null &&
                          foto == null &&
                          atual == null &&
                          !iniciando)
                        TextButton(
                          onPressed: iniciar,
                          child: const Text('Tentar novamente'),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
