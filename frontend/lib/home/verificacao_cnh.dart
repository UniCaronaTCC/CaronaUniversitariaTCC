import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../config/app_colors.dart';
import '../models/verificacao_cnh.dart';
import '../services/auth_service.dart';
import '../services/foto_cnh_temporaria.dart'
    if (dart.library.io) '../services/foto_cnh_temporaria_io.dart';
import '../services/verificacao_cnh_service.dart';
import '../widgets/componentes_padrao.dart';

typedef CapturarFotoCnh = Future<XFile?> Function();
typedef EnviarFotosCnh =
    Future<Map<String, dynamic>> Function(
      Uint8List frente,
      Uint8List verso,
      bool aceite,
    );

class VerificacaoCnhTela extends StatefulWidget {
  final Future<Map<String, dynamic>> Function()? carregarPerfil;
  final CapturarFotoCnh? capturarFoto;
  final EnviarFotosCnh? enviarFotos;

  const VerificacaoCnhTela({
    super.key,
    this.carregarPerfil,
    this.capturarFoto,
    this.enviarFotos,
  });

  @override
  State<VerificacaoCnhTela> createState() => _VerificacaoCnhTelaState();
}

class _VerificacaoCnhTelaState extends State<VerificacaoCnhTela> {
  VerificacaoCnh verificacao = VerificacaoCnh.fromPerfil(
    AuthService.usuarioLogado ?? {},
  );
  Uint8List? frente;
  Uint8List? verso;
  bool aceite = false;
  bool carregando = true;
  bool capturando = false;
  bool enviando = false;
  bool aprovadaAgora = false;
  String? erro;

  bool get aprovada => aprovadaAgora || verificacao.permiteOferecerCarona();
  bool get ocupada => carregando || capturando || enviando;

  @override
  void initState() {
    super.initState();
    atualizarStatus();
  }

  Future<void> atualizarStatus() async {
    setState(() {
      carregando = true;
      erro = null;
    });
    try {
      final resultado =
          await (widget.carregarPerfil?.call() ?? AuthService.buscarPerfil())
              .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (resultado['sucesso'] == true && resultado['dados'] is Map) {
        verificacao = VerificacaoCnh.fromPerfil(
          Map<String, dynamic>.from(resultado['dados']),
        );
        if (verificacao.permiteOferecerCarona()) descartarImagens();
      } else {
        erro =
            resultado['mensagem']?.toString() ??
            'Não foi possível atualizar o status';
      }
    } catch (_) {
      if (mounted) erro = 'Não foi possível atualizar o status';
    } finally {
      if (mounted) setState(() => carregando = false);
    }
  }

  Future<void> fotografar(bool fotografarFrente) async {
    if (!aceite || ocupada) return;
    setState(() {
      capturando = true;
      erro = null;
    });
    Uint8List? bytes;
    try {
      final foto =
          await (widget.capturarFoto?.call() ??
              ImagePicker().pickImage(
                source: ImageSource.camera,
                preferredCameraDevice: CameraDevice.rear,
                maxWidth: 2600,
                maxHeight: 2600,
                imageQuality: 95,
                requestFullMetadata: false,
              ));
      if (foto == null) return;
      try {
        bytes = await foto.readAsBytes();
      } finally {
        if (widget.capturarFoto == null) await descartarFotoCnh(foto.path);
      }
      if (!mounted) {
        bytes.fillRange(0, bytes.length, 0);
        return;
      }
      if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
        bytes.fillRange(0, bytes.length, 0);
        erro = 'A foto deve ter até 5 MB. Tire outra foto';
        return;
      }
      final anterior = fotografarFrente ? frente : verso;
      anterior?.fillRange(0, anterior.length, 0);
      if (fotografarFrente) {
        frente = bytes;
      } else {
        verso = bytes;
      }
    } catch (_) {
      if (mounted) {
        erro =
            'Não foi possível abrir a câmera. Confira a permissão e tente novamente';
      }
    } finally {
      if (mounted) setState(() => capturando = false);
    }
  }

  void descartarImagens() {
    frente?.fillRange(0, frente!.length, 0);
    verso?.fillRange(0, verso!.length, 0);
    frente = null;
    verso = null;
  }

  Future<void> enviar() async {
    if (ocupada || !aceite || frente == null || verso == null) return;
    setState(() {
      enviando = true;
      erro = null;
    });
    try {
      final resultado =
          await (widget.enviarFotos?.call(frente!, verso!, aceite) ??
              const VerificacaoCnhService().enviar(
                frente!,
                verso!,
                aceitePrivacidade: aceite,
              ));
      if (!mounted) return;
      if (resultado['sucesso'] == true && resultado['dados'] is Map) {
        final status = resultado['dados']['status']?.toString();
        aprovadaAgora = status == 'APROVADA';
        descartarImagens();
        await atualizarStatus();
        if (!mounted) return;
        if (!aprovadaAgora) {
          erro =
              'Não conseguimos conferir seus dados. Fotografe o documento inteiro, com boa luz e sem reflexos';
        }
      } else {
        erro =
            resultado['mensagem']?.toString() ??
            'Não foi possível conferir a CNH';
      }
    } catch (_) {
      if (mounted) erro = 'Não foi possível enviar as fotos. Tente novamente';
    } finally {
      if (mounted) setState(() => enviando = false);
    }
  }

  @override
  void dispose() {
    descartarImagens();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !enviando,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: const BarraSuperiorPadrao(titulo: 'Verificar CNH'),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (carregando) const LinearProgressIndicator(),
              if (aprovada) ...[
                const EstadoConteudoPadrao(
                  icone: Icons.verified_outlined,
                  corIcone: Colors.green,
                  titulo: 'CNH conferida',
                  mensagem: 'Você já pode oferecer caronas',
                ),
                if (verificacao.permiteOferecerCarona())
                  Text(
                    'Categoria ${verificacao.categoria} · Válida até ${verificacao.validadeFormatada}',
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: ocupada
                      ? null
                      : () => Navigator.pop(context, true),
                  icon: const Icon(Icons.check),
                  label: const Text('Concluir'),
                ),
              ] else ...[
                const Text(
                  'Antes de oferecer caronas',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Precisamos conferir seu nome, CPF, categoria e validade da CNH. Guardamos esses dados e os últimos quatro dígitos do registro; as fotos são descartadas após a leitura.',
                  style: TextStyle(height: 1.4),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: aceite,
                  onChanged: ocupada
                      ? null
                      : (valor) => setState(() {
                          aceite = valor ?? false;
                          if (!aceite) descartarImagens();
                        }),
                  title: const Text(
                    'Li e concordo com o uso desses dados para verificar minha CNH',
                  ),
                ),
                const SizedBox(height: 12),
                _FotoCnh(
                  titulo: 'Frente da CNH',
                  bytes: frente,
                  habilitada: aceite && !ocupada,
                  onFotografar: () => fotografar(true),
                ),
                const SizedBox(height: 16),
                _FotoCnh(
                  titulo: 'Verso da CNH',
                  bytes: verso,
                  habilitada: aceite && !ocupada,
                  onFotografar: () => fotografar(false),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed:
                      ocupada || !aceite || frente == null || verso == null
                      ? null
                      : enviar,
                  icon: enviando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.fact_check_outlined),
                  label: Text(
                    enviando ? 'Conferindo CNH...' : 'Enviar para verificação',
                  ),
                ),
              ],
              if (erro != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    erro!,
                    style: const TextStyle(color: Colors.red, height: 1.4),
                    semanticsLabel: erro,
                  ),
                ),
              TextButton.icon(
                onPressed: ocupada ? null : atualizarStatus,
                icon: const Icon(Icons.refresh),
                label: const Text('Atualizar status'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FotoCnh extends StatelessWidget {
  final String titulo;
  final Uint8List? bytes;
  final bool habilitada;
  final VoidCallback onFotografar;

  const _FotoCnh({
    required this.titulo,
    this.bytes,
    required this.habilitada,
    required this.onFotografar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 1.6,
            child: bytes == null
                ? const ColoredBox(
                    color: Color(0xFFF4F4F4),
                    child: Icon(
                      Icons.credit_card_outlined,
                      size: 48,
                      color: Colors.black38,
                    ),
                  )
                : Image.memory(
                    bytes!,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => const Center(
                      child: Text('Foto inválida. Tire outra foto'),
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: habilitada ? onFotografar : null,
            icon: const Icon(Icons.camera_alt_outlined),
            label: Text(bytes == null ? 'Fotografar' : 'Refazer foto'),
          ),
        ],
      ),
    );
  }
}
