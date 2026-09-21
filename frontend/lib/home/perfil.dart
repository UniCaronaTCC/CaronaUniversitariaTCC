import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../auth/login.dart';
import '../config/app_colors.dart';
import '../models/instituicao.dart';
import '../navigation/navegacao_principal.dart';
import '../services/avaliacao_service.dart';
import '../services/auth_service.dart';
import '../widgets/barra_navegacao_home.dart';
import '../widgets/campo_busca_instituicao.dart';
import '../widgets/componentes_padrao.dart';
import '../widgets/foto_perfil.dart';
import 'avaliacoes_recebidas.dart';
import 'historico_caronas.dart';

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
    final modeloController = TextEditingController(
      text: veiculoAtual['modelo']?.toString() ?? '',
    );
    final corController = TextEditingController(
      text: veiculoAtual['cor']?.toString() ?? '',
    );
    final placaController = TextEditingController(
      text: veiculoAtual['placa']?.toString() ?? '',
    );
    String? erroFormulario;

    final dados = await showDialog<List<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, atualizarDialogo) => AlertDialog(
          title: Text(
            veiculoAtual.isEmpty ? 'Cadastrar veículo' : 'Editar veículo',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: modeloController,
                  textCapitalization: TextCapitalization.words,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    labelText: 'Modelo',
                    hintText: 'Ex.: Honda Civic',
                  ),
                ),
                TextField(
                  controller: corController,
                  textCapitalization: TextCapitalization.words,
                  maxLength: 50,
                  decoration: const InputDecoration(
                    labelText: 'Cor',
                    hintText: 'Ex.: Prata',
                  ),
                ),
                TextField(
                  controller: placaController,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 7,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
                    TextInputFormatter.withFunction((antigo, novo) {
                      return novo.copyWith(text: novo.text.toUpperCase());
                    }),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Placa',
                    hintText: 'ABC1D23',
                  ),
                ),
                if (erroFormulario != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      erroFormulario!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
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
              onPressed: () {
                final modelo = modeloController.text.trim();
                final cor = corController.text.trim();
                final placa = placaController.text.trim().toUpperCase();

                if (modelo.length < 2 || cor.length < 2) {
                  atualizarDialogo(
                    () => erroFormulario = 'Informe o modelo e a cor',
                  );
                  return;
                }

                if (!RegExp(
                  r'^[A-Z]{3}(?:\d{4}|\d[A-Z]\d{2})$',
                ).hasMatch(placa)) {
                  atualizarDialogo(
                    () => erroFormulario = 'Informe uma placa válida',
                  );
                  return;
                }

                Navigator.pop(context, [modelo, cor, placa]);
              },
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
        await (widget.salvarVeiculo?.call(dados[0], dados[1], dados[2]) ??
            AuthService.salvarVeiculo(dados[0], dados[1], dados[2]));

    if (!mounted) {
      return;
    }

    setState(() {
      carregando = false;
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
    final nome = usuario['nome']?.toString().trim() ?? '';
    final email = usuario['email']?.toString().trim() ?? '';
    final instituicao = usuario['instituicao']?.toString().trim() ?? '';
    final campus = usuario['campus']?.toString().trim() ?? '';
    final tipoPerfil = usuario['tipoPerfil']?.toString().trim() ?? 'PASSAGEIRO';
    final statusVerificacao =
        usuario['statusVerificacao']?.toString().trim() ?? 'NAO_ENVIADO';
    final fotoPerfil = usuario['fotoPerfil']?.toString().trim();
    final mediaExibida = mediaAvaliacao.clamp(0, 5).toDouble();
    final textoMedia = mediaExibida.toStringAsFixed(1).replaceAll('.', ',');
    final textoTotalAvaliacoes = totalAvaliacoes == 0
        ? 'Sem avaliações'
        : totalAvaliacoes == 1
        ? '1 avaliação'
        : '$totalAvaliacoes avaliações';
    final instituicaoCompleta = [
      instituicao,
      if (campus.isNotEmpty) 'Campus $campus',
    ].where((texto) => texto.isNotEmpty).join(' - ');
    final veiculo = usuario['veiculo'] is Map
        ? Map<String, dynamic>.from(usuario['veiculo'])
        : null;

    return Scaffold(
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
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (carregando) const LinearProgressIndicator(),
            if (carregando) const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F5FA),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black12),
              ),
              child: Column(
                children: [
                  FotoPerfil(
                    nome: nome,
                    urlFoto: fotoPerfil,
                    carregando: enviandoFoto,
                    onTap: carregando ? null : alterarFoto,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    nome.isNotEmpty ? nome : 'Usuário',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    instituicaoCompleta.isNotEmpty
                        ? instituicaoCompleta
                        : 'Instituição não informada',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    textoTipoPerfil(tipoPerfil),
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        iconeVerificacao(statusVerificacao),
                        color: corVerificacao(statusVerificacao),
                        size: 18,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        textoVerificacao(statusVerificacao),
                        style: TextStyle(
                          color: corVerificacao(statusVerificacao),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: abrirAvaliacoes,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star,
                                color: AppColors.primary,
                                size: 24,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$textoMedia / 5',
                                style: const TextStyle(
                                  color: AppColors.text,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.chevron_right,
                                color: Colors.black45,
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            mensagemErroAvaliacoes ?? textoTotalAvaliacoes,
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (mensagemErro != null) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: carregarDados,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar atualizar novamente'),
              ),
            ],
            const SizedBox(height: 32),
            const Text(
              'Sua atividade',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history, color: AppColors.primary),
              title: const Text('Histórico de caronas'),
              subtitle: const Text('Como motorista e passageiro'),
              trailing: const Icon(Icons.chevron_right),
              onTap: abrirHistorico,
            ),
            const SizedBox(height: 24),
            const Text(
              'Meu veículo',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8F5FA),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black12),
              ),
              child: ListTile(
                leading: const Icon(
                  Icons.directions_car_outlined,
                  color: AppColors.primary,
                ),
                title: Text(
                  veiculo?['modelo']?.toString() ?? 'Cadastrar veículo',
                ),
                subtitle: Text(
                  veiculo == null
                      ? 'Necessário para oferecer caronas'
                      : '${veiculo['cor']} • ${veiculo['placa']}',
                ),
                trailing: Icon(
                  veiculo == null ? Icons.add : Icons.edit_outlined,
                ),
                onTap: carregando ? null : editarVeiculo,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Dados da conta',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            itemPerfil(
              icone: Icons.person_outline,
              titulo: 'Nome',
              valor: nome.isNotEmpty ? nome : 'Não informado',
            ),
            const Divider(),
            itemPerfil(
              icone: Icons.email_outlined,
              titulo: 'E-mail',
              valor: email.isNotEmpty ? email : 'Não informado',
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: sair,
                icon: const Icon(Icons.logout),
                label: const Text('Sair'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
