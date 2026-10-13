import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../config/app_colors.dart';
import '../models/verificacao_cnh.dart';
import '../services/auth_service.dart';
import '../services/verificacao_cnh_service.dart';
import '../widgets/componentes_padrao.dart';
import '../widgets/foto_cnh.dart';
import 'selecionar_foto_cnh.dart';

typedef CapturarFotoCnh = Future<XFile?> Function();
typedef EnviarFotosCnh =
    Future<Map<String, dynamic>> Function(
      Uint8List frente,
      Uint8List verso,
      bool aceite,
      String nomeCompleto,
    );

class VerificacaoCnhTela extends StatefulWidget {
  final Future<Map<String, dynamic>> Function()? carregarPerfil;
  final CapturarFotoCnh? capturarFoto;
  final CapturarFotoCnh? escolherFoto;
  final Future<Uint8List?> Function(Uint8List)? recortarFoto;
  final EnviarFotosCnh? enviarFotos;
  final Future<Map<String, dynamic>> Function()? reiniciarTeste;

  const VerificacaoCnhTela({
    super.key,
    this.carregarPerfil,
    this.capturarFoto,
    this.escolherFoto,
    this.recortarFoto,
    this.enviarFotos,
    this.reiniciarTeste,
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
  bool reiniciando = false;
  String? erro;
  final nomeCompleto = TextEditingController();

  bool get aprovada => aprovadaAgora || verificacao.permiteOferecerCarona();
  bool get ocupada => carregando || capturando || enviando || reiniciando;

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
        aprovadaAgora = verificacao.permiteOferecerCarona();
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

  Future<void> reiniciarParaTeste() async {
    if (ocupada || !aprovada) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reiniciar CNH para teste?'),
        content: const Text(
          'A aprovação e os dados da CNH serão removidos. Você precisará enviar o documento novamente. Seu perfil, veículo e histórico serão preservados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reiniciar'),
          ),
        ],
      ),
    );
    if (!mounted || confirmar != true || ocupada) return;
    setState(() {
      reiniciando = true;
      erro = null;
    });
    try {
      final resultado =
          await (widget.reiniciarTeste?.call() ??
              const VerificacaoCnhService().reiniciarTeste());
      if (!mounted) return;
      if (resultado['sucesso'] == true) {
        aprovadaAgora = false;
        verificacao = const VerificacaoCnh();
        aceite = false;
        nomeCompleto.clear();
        descartarImagens();
        await atualizarStatus();
      } else {
        erro =
            resultado['mensagem']?.toString() ??
            'Não foi possível reiniciar a CNH';
      }
    } catch (_) {
      if (mounted) {
        erro = 'Não foi possível confirmar o reinício. Atualize o status';
      }
    } finally {
      if (mounted) setState(() => reiniciando = false);
    }
  }

  Future<void> fotografar(
    bool fotografarFrente, {
    ImageSource origem = ImageSource.camera,
  }) async {
    if (!aceite || ocupada) return;
    setState(() {
      capturando = true;
      erro = null;
    });
    Uint8List? bytes;
    try {
      bytes = await selecionarFotoCnh(
        context,
        lado: fotografarFrente ? 'Frente da CNH' : 'Verso da CNH',
        origem: origem,
        capturar: widget.capturarFoto,
        escolher: widget.escolherFoto,
        recortar: widget.recortarFoto,
      );
      if (bytes == null) return;
      if (!mounted) {
        bytes.fillRange(0, bytes.length, 0);
        return;
      }
      final anterior = fotografarFrente ? frente : verso;
      anterior?.fillRange(0, anterior.length, 0);
      if (fotografarFrente) {
        frente = bytes;
      } else {
        verso = bytes;
      }
    } on FormatException catch (e) {
      if (mounted) erro = e.message;
    } catch (_) {
      if (mounted) {
        erro =
            'Não foi possível obter a foto. Confira a permissão e tente novamente';
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
    if (nomeCompleto.text.trim().split(RegExp(r'\s+')).length < 2) {
      setState(() => erro = 'Informe seu nome completo conforme a CNH');
      return;
    }
    setState(() {
      enviando = true;
      erro = null;
    });
    try {
      final resultado =
          await (widget.enviarFotos?.call(
                frente!,
                verso!,
                aceite,
                nomeCompleto.text.trim(),
              ) ??
              const VerificacaoCnhService().enviar(
                frente!,
                verso!,
                aceitePrivacidade: aceite,
                nomeCompleto: nomeCompleto.text.trim(),
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
              resultado['mensagem']?.toString() ??
              'Não conseguimos conferir os dados da CNH. Confira as fotos e tente novamente';
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
    nomeCompleto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !enviando && !reiniciando,
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
                TextButton.icon(
                  onPressed: ocupada ? null : reiniciarParaTeste,
                  icon: const Icon(Icons.restart_alt),
                  label: Text(
                    reiniciando ? 'Reiniciando...' : 'Reiniciar CNH (teste)',
                  ),
                ),
              ] else ...[
                const Text(
                  'Antes de oferecer caronas',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Conferimos o nome completo informado com a foto, sem alterar seu nome de perfil. Guardamos CPF, categoria e validade. O nome informado é usado somente na conferência e as fotos são descartadas após a leitura.',
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
                TextField(
                  controller: nomeCompleto,
                  enabled: aceite && !ocupada,
                  maxLength: 150,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nome completo conforme a CNH',
                  ),
                ),
                const SizedBox(height: 12),
                FotoCnh(
                  titulo: 'Frente da CNH',
                  bytes: frente,
                  habilitada: aceite && !ocupada,
                  onFotografar: () => fotografar(true),
                  onEscolherGaleria: () =>
                      fotografar(true, origem: ImageSource.gallery),
                ),
                const SizedBox(height: 16),
                FotoCnh(
                  titulo: 'Verso da CNH',
                  bytes: verso,
                  habilitada: aceite && !ocupada,
                  onFotografar: () => fotografar(false),
                  onEscolherGaleria: () =>
                      fotografar(false, origem: ImageSource.gallery),
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
