import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../auth/login.dart';
import '../config/app_colors.dart';
import '../models/instituicao.dart';
import '../models/verificacao_cnh.dart';
import '../navigation/navegacao_principal.dart';
import '../services/avaliacao_service.dart';
import '../services/auth_service.dart';
import '../services/mensagem_service.dart';
import '../services/solicitacao_service.dart';
import '../widgets/barra_navegacao_home.dart';
import '../widgets/aviso_app.dart';
import '../widgets/campo_busca_instituicao.dart';
import '../widgets/componentes_padrao.dart';
import '../widgets/conteudo_perfil_buscaeu.dart';
import '../widgets/visual_buscaeu.dart';
import '../widgets/dialogo_veiculo.dart';
import 'avaliacoes_recebidas.dart';
import 'historico_caronas.dart';
import 'recorrencias.dart';
import 'verificacao_cnh.dart';

typedef CarregarPerfil = Future<Map<String, dynamic>> Function();
typedef AtualizarPerfil =
    Future<Map<String, dynamic>> Function(int idInstituicao, String campus);
typedef SelecionarFotoPerfil = Future<XFile?> Function();
typedef EnviarFotoPerfil =
    Future<Map<String, dynamic>> Function(String caminho);

typedef RemoverFotoPerfil =
    Future<Map<String, dynamic>> Function(String fotoAtual);

enum _AcaoFotoPerfil { camera, galeria, remover }

typedef SalvarVeiculo =
    Future<Map<String, dynamic>> Function(
      String modelo,
      String cor,
      String placa,
    );

class _DadosPerfilEditado {
  final int idInstituicao;
  final String campus;

  const _DadosPerfilEditado(this.idInstituicao, this.campus);
}

class PerfilTela extends StatefulWidget {
  final CarregarPerfil? carregarPerfil;
  final AtualizarPerfil? atualizarPerfil;
  final CarregarAvaliacoes? carregarAvaliacoes;
  final BuscarInstituicoes? buscarInstituicoes;
  final SelecionarFotoPerfil? selecionarFoto;
  final SelecionarFotoPerfil? capturarFoto;
  final EnviarFotoPerfil? enviarFoto;
  final RemoverFotoPerfil? removerFoto;
  final SalvarVeiculo? salvarVeiculo;

  const PerfilTela({
    super.key,
    this.carregarPerfil,
    this.atualizarPerfil,
    this.carregarAvaliacoes,
    this.buscarInstituicoes,
    this.selecionarFoto,
    this.capturarFoto,
    this.enviarFoto,
    this.removerFoto,
    this.salvarVeiculo,
  });

  @override
  State<PerfilTela> createState() => _PerfilTelaState();
}

class _PerfilTelaState extends State<PerfilTela> {
  Map<String, dynamic> usuario = AuthService.usuarioLogado ?? {};
  bool carregando = true;
  bool enviandoFoto = false;
  bool _selecionandoFoto = false;
  String? mensagemErro;
  String? mensagemErroAvaliacoes;
  double mediaAvaliacao = 0;
  int totalAvaliacoes = 0;

  void _mostrarAviso(String mensagem, {required TipoAviso tipo}) {
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    AvisoApp.mostrar(context, mensagem, tipo: tipo);
  }

  @override
  void initState() {
    super.initState();
    carregarDados();
  }

  Future<void> carregarDados() async {
    setState(() {
      carregando = true;
      mensagemErro = null;
      mensagemErroAvaliacoes = null;
    });

    final resultadoPerfil =
        await (widget.carregarPerfil?.call() ?? AuthService.buscarPerfil());

    if (!mounted) {
      return;
    }

    if (resultadoPerfil['sucesso'] != true ||
        resultadoPerfil['dados'] is! Map) {
      setState(() {
        carregando = false;
        mensagemErro = resultadoPerfil['mensagem']?.toString();
      });
      return;
    }

    final novoUsuario = Map<String, dynamic>.from(resultadoPerfil['dados']);
    final idUsuario = int.tryParse(novoUsuario['id']?.toString() ?? '');
    Map<String, dynamic>? dadosAvaliacoes;
    String? erroAvaliacoes;

    if (idUsuario != null) {
      final resultadoAvaliacoes =
          await (widget.carregarAvaliacoes?.call(idUsuario, 1) ??
              AvaliacaoService.listarRecebidas(idUsuario));

      if (resultadoAvaliacoes['sucesso'] == true &&
          resultadoAvaliacoes['dados'] is Map) {
        dadosAvaliacoes = Map<String, dynamic>.from(
          resultadoAvaliacoes['dados'],
        );
      } else {
        erroAvaliacoes = resultadoAvaliacoes['mensagem']?.toString();
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      usuario = novoUsuario;
      mediaAvaliacao =
          double.tryParse(dadosAvaliacoes?['media']?.toString() ?? '') ?? 0;
      totalAvaliacoes =
          int.tryParse(dadosAvaliacoes?['total']?.toString() ?? '') ?? 0;
      mensagemErroAvaliacoes = erroAvaliacoes;
      carregando = false;
    });
  }

  void abrirAvaliacoes() {
    final idUsuario = int.tryParse(usuario['id']?.toString() ?? '');

    if (idUsuario == null) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AvaliacoesRecebidasTela(
          idUsuario: idUsuario,
          nomeUsuario: usuario['nome']?.toString() ?? 'Usuário',
          carregarAvaliacoes: widget.carregarAvaliacoes,
        ),
      ),
    );
  }

  void abrirHistorico() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HistoricoCaronasTela()),
    );
  }

  Future<void> abrirVerificacaoCnh() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            VerificacaoCnhTela(carregarPerfil: widget.carregarPerfil),
      ),
    );
    if (mounted) await carregarDados();
  }

  Future<void> editarPerfil() async {
    if (enviandoFoto || _selecionandoFoto) return;
    final nomeInstituicao = usuario['instituicao']?.toString() ?? '';
    final idInstituicao = int.tryParse(
      usuario['idInstituicao']?.toString() ?? '',
    );
    final campusAtual = usuario['campus']?.toString() ?? '';
    Instituicao? instituicaoSelecionada;

    if (idInstituicao != null && nomeInstituicao.isNotEmpty) {
      instituicaoSelecionada = Instituicao(
        id: idInstituicao,
        nome: nomeInstituicao,
        sigla: null,
        campus: campusAtual,
        municipio: '',
        uf: '',
      );
    }

    final dados = await showDialog<_DadosPerfilEditado>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, atualizarDialogo) => AlertDialog(
          title: const Text('Editar perfil'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CampoBuscaInstituicao(
                  valorInicial: nomeInstituicao,
                  buscarInstituicoes: widget.buscarInstituicoes,
                  onChanged: (instituicao) {
                    atualizarDialogo(
                      () => instituicaoSelecionada = instituicao,
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: instituicaoSelecionada == null
                  ? null
                  : () => Navigator.pop(
                      context,
                      _DadosPerfilEditado(
                        instituicaoSelecionada!.id,
                        instituicaoSelecionada!.campus,
                      ),
                    ),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || dados == null) {
      return;
    }

    setState(() => carregando = true);

    final resultado =
        await (widget.atualizarPerfil?.call(
              dados.idInstituicao,
              dados.campus,
            ) ??
            AuthService.atualizarPerfil(dados.idInstituicao, dados.campus));

    if (!mounted) {
      return;
    }

    setState(() {
      carregando = false;

      if (resultado['sucesso'] == true && resultado['dados'] is Map) {
        usuario = Map<String, dynamic>.from(resultado['dados']);
      }
    });

    _mostrarAviso(
      resultado['mensagem']?.toString() ??
          (resultado['sucesso'] == true
              ? 'Perfil atualizado com sucesso'
              : 'Erro ao atualizar perfil'),
      tipo: resultado['sucesso'] == true ? TipoAviso.sucesso : TipoAviso.erro,
    );
  }

  Future<void> alterarFoto() async {
    if (carregando || enviandoFoto || _selecionandoFoto) return;
    _selecionandoFoto = true;
    final contaInicial = AuthService.usuarioLogado?['id'];
    bool mesmaConta() => AuthService.usuarioLogado?['id'] == contaInicial;
    _AcaoFotoPerfil? acao;
    var enviando = false;
    try {
      final fotoAtual = usuario['fotoPerfil']?.toString().trim() ?? '';
      acao = await showModalBottomSheet<_AcaoFotoPerfil>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('Tirar foto'),
                  onTap: () => Navigator.pop(context, _AcaoFotoPerfil.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Escolher da galeria'),
                  onTap: () => Navigator.pop(context, _AcaoFotoPerfil.galeria),
                ),
                if (fotoAtual.isNotEmpty)
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline,
                      color: Color(0xFFC62828),
                    ),
                    title: const Text(
                      'Remover foto',
                      style: TextStyle(color: Color(0xFFC62828)),
                    ),
                    onTap: () =>
                        Navigator.pop(context, _AcaoFotoPerfil.remover),
                  ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      );
      if (!mounted || acao == null || !mesmaConta()) return;
      Map<String, dynamic> resultado;
      if (acao == _AcaoFotoPerfil.remover) {
        final confirmou = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Remover foto de perfil?'),
            content: const Text(
              'A inicial do seu nome aparecerá no lugar da foto.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFC62828),
                ),
                child: const Text('Remover'),
              ),
            ],
          ),
        );
        if (!mounted || confirmou != true || !mesmaConta()) return;
        setState(() => enviandoFoto = true);
        enviando = true;
        resultado =
            await (widget.removerFoto?.call(fotoAtual) ??
                AuthService.removerFotoPerfil(fotoAtual));
      } else {
        final camera = acao == _AcaoFotoPerfil.camera;
        final selecionar = camera ? widget.capturarFoto : widget.selecionarFoto;
        final foto =
            await (selecionar?.call() ??
                ImagePicker().pickImage(
                  source: camera ? ImageSource.camera : ImageSource.gallery,
                  preferredCameraDevice: CameraDevice.front,
                  maxWidth: 1024,
                  maxHeight: 1024,
                  imageQuality: 80,
                ));
        if (foto == null || !mounted || !mesmaConta()) return;
        setState(() => enviandoFoto = true);
        enviando = true;
        resultado =
            await (widget.enviarFoto?.call(foto.path) ??
                AuthService.atualizarFotoPerfil(foto.path));
      }
      if (!mounted || !mesmaConta()) return;
      setState(() {
        enviandoFoto = false;
        if (resultado['sucesso'] == true && resultado['dados'] is Map) {
          usuario = Map<String, dynamic>.from(resultado['dados']);
        }
      });
      final sucesso = resultado['sucesso'] == true;
      final aviso = sucesso ? resultado['aviso']?.toString() : null;
      _mostrarAviso(
        aviso ??
            resultado['mensagem']?.toString() ??
            (sucesso
                ? (acao == _AcaoFotoPerfil.remover
                      ? 'Foto removida do perfil'
                      : 'Foto atualizada com sucesso')
                : (acao == _AcaoFotoPerfil.remover
                      ? 'Não foi possível remover a foto'
                      : 'Não foi possível atualizar a foto')),
        tipo: !sucesso
            ? TipoAviso.erro
            : aviso != null
            ? TipoAviso.atencao
            : TipoAviso.sucesso,
      );
    } on PlatformException catch (erro) {
      if (!mounted || !mesmaConta()) return;
      final negado =
          erro.code.contains('access_denied') ||
          erro.code.contains('restricted');
      _mostrarAviso(
        enviando
            ? (acao == _AcaoFotoPerfil.remover
                  ? 'Não foi possível remover a foto. Tente novamente'
                  : 'Não foi possível atualizar a foto. Tente novamente')
            : negado
            ? (acao == _AcaoFotoPerfil.camera
                  ? 'Permita o acesso à câmera nas configurações do celular para tirar uma foto'
                  : 'Permita o acesso às fotos nas configurações do celular')
            : 'Não foi possível abrir ${acao == _AcaoFotoPerfil.camera ? 'a câmera' : 'a galeria'}. Tente novamente',
        tipo: TipoAviso.erro,
      );
    } catch (erro) {
      if (!mounted || !mesmaConta()) return;
      _mostrarAviso(
        acao == _AcaoFotoPerfil.remover
            ? 'Não foi possível remover a foto. Tente novamente'
            : enviando
            ? 'Não foi possível atualizar a foto. Tente novamente'
            : 'Não foi possível selecionar a foto',
        tipo: TipoAviso.erro,
      );
    } finally {
      _selecionandoFoto = false;
      if (mounted) setState(() => enviandoFoto = false);
    }
  }

  Future<void> sair() async {
    await MensagemService.pararContadorMensagensNaoLidas();
    SolicitacaoService.pararContadorSolicitacoesPendentes();
    await AuthService.sair();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginTela()),
      (_) => false,
    );
  }

  Future<void> editarVeiculo() async {
    if (enviandoFoto || _selecionandoFoto) return;
    final veiculoAtual = usuario['veiculo'] is Map
        ? Map<String, dynamic>.from(usuario['veiculo'])
        : <String, dynamic>{};
    final resultado = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DialogoVeiculo(
        veiculo: veiculoAtual,
        salvar: widget.salvarVeiculo ?? AuthService.salvarVeiculo,
      ),
    );

    if (!mounted || resultado == null) {
      return;
    }

    setState(() {
      if (resultado['sucesso'] == true && resultado['dados'] is Map) {
        usuario = {
          ...usuario,
          'veiculo': Map<String, dynamic>.from(resultado['dados']),
        };
      }
    });

    _mostrarAviso(
      resultado['mensagem']?.toString() ??
          (resultado['sucesso'] == true
              ? 'Veículo salvo com sucesso'
              : 'Erro ao salvar veículo'),
      tipo: resultado['sucesso'] == true ? TipoAviso.sucesso : TipoAviso.erro,
    );
  }

  Widget itemPerfil({
    required IconData icone,
    required String titulo,
    required String valor,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icone, color: AppColors.primary),
      title: Text(titulo),
      subtitle: Text(valor),
    );
  }

  String textoTipoPerfil() {
    final cnh = VerificacaoCnh.fromPerfil(usuario);
    return cnh.permiteOferecerCarona()
        ? 'Passageiro e motorista'
        : 'Passageiro';
  }

  String textoVerificacao(String status) {
    if (status == 'APROVADO') {
      return 'Perfil verificado';
    }

    if (status == 'PENDENTE') {
      return 'Verificação pendente';
    }

    if (status == 'RECUSADO') {
      return 'Verificação recusada';
    }

    return 'Perfil não verificado';
  }

  IconData iconeVerificacao(String status) {
    if (status == 'APROVADO') {
      return Icons.verified;
    }

    if (status == 'PENDENTE') {
      return Icons.schedule;
    }

    if (status == 'RECUSADO') {
      return Icons.error_outline;
    }

    return Icons.verified_outlined;
  }

  Color corVerificacao(String status) {
    if (status == 'APROVADO') {
      return Colors.green;
    }

    if (status == 'PENDENTE') {
      return Colors.orange;
    }

    if (status == 'RECUSADO') {
      return Colors.red;
    }

    return Colors.black54;
  }

  @override
  Widget build(BuildContext context) {
    final status =
        usuario['statusVerificacao']?.toString().trim() ?? 'NAO_ENVIADO';
    // O selo representa a conferencia interna, sem alterar a verificacao salva.
    final statusVisual =
        VerificacaoCnh.fromPerfil(usuario).permiteOferecerCarona()
        ? 'APROVADO'
        : status;
    return VisualBuscaEu(
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: BarraSuperiorPadrao(
          titulo: 'Perfil',
          actions: [
            IconButton(
              tooltip: 'Editar perfil',
              onPressed: carregando ? null : editarPerfil,
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
        bottomNavigationBar: BarraNavegacaoHome(
          currentIndex: 3,
          onTap: (indice) =>
              NavegacaoPrincipal.selecionar(context, indice, indiceAtual: 3),
        ),
        body: SafeArea(
          child: ConteudoPerfilBuscaEu(
            usuario: usuario,
            carregando: carregando,
            enviandoFoto: enviandoFoto,
            media: mediaAvaliacao,
            totalAvaliacoes: totalAvaliacoes,
            erro: mensagemErro,
            erroAvaliacoes: mensagemErroAvaliacoes,
            tipoPerfil: textoTipoPerfil(),
            situacaoPerfil: textoVerificacao(statusVisual),
            iconeSituacao: iconeVerificacao(statusVisual),
            corSituacao: corVerificacao(statusVisual),
            onFoto: alterarFoto,
            onEditar: editarPerfil,
            onVeiculo: editarVeiculo,
            onCnh: abrirVerificacaoCnh,
            onAvaliacoes: abrirAvaliacoes,
            onHistorico: abrirHistorico,
            onSair: sair,
            onRecarregar: carregarDados,
            onRecorrencias: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RecorrenciasTela()),
            ),
          ),
        ),
      ),
    );
  }
}
