import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../auth/login.dart';
import '../config/app_colors.dart';
import '../models/instituicao.dart';
import '../navigation/navegacao_principal.dart';
import '../services/avaliacao_service.dart';
import '../services/auth_service.dart';
import '../services/mensagem_service.dart';
import '../services/solicitacao_service.dart';
import '../widgets/barra_navegacao_home.dart';
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
  final EnviarFotoPerfil? enviarFoto;
  final SalvarVeiculo? salvarVeiculo;

  const PerfilTela({
    super.key,
    this.carregarPerfil,
    this.atualizarPerfil,
    this.carregarAvaliacoes,
    this.buscarInstituicoes,
    this.selecionarFoto,
    this.enviarFoto,
    this.salvarVeiculo,
  });

  @override
  State<PerfilTela> createState() => _PerfilTelaState();
}

class _PerfilTelaState extends State<PerfilTela> {
  Map<String, dynamic> usuario = AuthService.usuarioLogado ?? {};
  bool carregando = true;
  bool enviandoFoto = false;
  String? mensagemErro;
  String? mensagemErroAvaliacoes;
  double mediaAvaliacao = 0;
  int totalAvaliacoes = 0;

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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          resultado['mensagem']?.toString() ?? 'Erro ao atualizar perfil',
        ),
      ),
    );
  }

  Future<void> alterarFoto() async {
    try {
      final foto =
          await (widget.selecionarFoto?.call() ??
              ImagePicker().pickImage(
                source: ImageSource.gallery,
                maxWidth: 1024,
                maxHeight: 1024,
                imageQuality: 80,
              ));

      if (foto == null || !mounted) {
        return;
      }

      setState(() => enviandoFoto = true);

      final resultado =
          await (widget.enviarFoto?.call(foto.path) ??
              AuthService.atualizarFotoPerfil(foto.path));

      if (!mounted) {
        return;
      }

      setState(() {
        enviandoFoto = false;

        if (resultado['sucesso'] == true && resultado['dados'] is Map) {
          usuario = Map<String, dynamic>.from(resultado['dados']);
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            resultado['mensagem']?.toString() ??
                'Não foi possível atualizar a foto',
          ),
        ),
      );
    } catch (erro) {
      if (!mounted) {
        return;
      }

      setState(() => enviandoFoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível selecionar a foto')),
      );
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          resultado['mensagem']?.toString() ?? 'Erro ao salvar veículo',
        ),
      ),
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

  String textoTipoPerfil(String tipoPerfil) {
    if (tipoPerfil == 'MOTORISTA') {
      return 'Motorista';
    }

    if (tipoPerfil == 'AMBOS') {
      return 'Motorista e passageiro';
    }

    return 'Passageiro';
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
            tipoPerfil: textoTipoPerfil(
              usuario['tipoPerfil']?.toString().trim() ?? 'PASSAGEIRO',
            ),
            situacaoPerfil: textoVerificacao(status),
            iconeSituacao: iconeVerificacao(status),
            corSituacao: corVerificacao(status),
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
