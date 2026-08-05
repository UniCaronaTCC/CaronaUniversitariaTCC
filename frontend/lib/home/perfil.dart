import 'package:flutter/material.dart';

import '../auth/login.dart';
import '../config/app_colors.dart';
import '../navigation/navegacao_principal.dart';
import '../services/auth_service.dart';
import '../widgets/barra_navegacao_home.dart';
import '../widgets/componentes_padrao.dart';

typedef CarregarPerfil = Future<Map<String, dynamic>> Function();
typedef AtualizarPerfil =
    Future<Map<String, dynamic>> Function(String instituicao, String campus);

class PerfilTela extends StatefulWidget {
  final CarregarPerfil? carregarPerfil;
  final AtualizarPerfil? atualizarPerfil;

  const PerfilTela({super.key, this.carregarPerfil, this.atualizarPerfil});

  @override
  State<PerfilTela> createState() => _PerfilTelaState();
}

class _PerfilTelaState extends State<PerfilTela> {
  Map<String, dynamic> usuario = AuthService.usuarioLogado ?? {};
  bool carregando = true;
  String? mensagemErro;

  @override
  void initState() {
    super.initState();
    carregarDados();
  }

  Future<void> carregarDados() async {
    setState(() {
      carregando = true;
      mensagemErro = null;
    });

    final resultado =
        await (widget.carregarPerfil?.call() ?? AuthService.buscarPerfil());

    if (!mounted) {
      return;
    }

    setState(() {
      carregando = false;

      if (resultado['sucesso'] == true && resultado['dados'] is Map) {
        usuario = Map<String, dynamic>.from(resultado['dados']);
      } else {
        mensagemErro = resultado['mensagem']?.toString();
      }
    });
  }

  Future<void> editarPerfil() async {
    var novaInstituicao = usuario['instituicao']?.toString() ?? '';
    var novoCampus = usuario['campus']?.toString() ?? '';

    final dados = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar perfil'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CampoTextoPadrao(
                label: 'Instituição',
                valorInicial: novaInstituicao,
                onChanged: (valor) => novaInstituicao = valor,
              ),
              const SizedBox(height: 16),
              CampoTextoPadrao(
                label: 'Campus',
                valorInicial: novoCampus,
                onChanged: (valor) => novoCampus = valor,
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
            onPressed: () => Navigator.pop(context, [
              novaInstituicao.trim(),
              novoCampus.trim(),
            ]),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (!mounted || dados == null) {
      return;
    }

    setState(() => carregando = true);

    final resultado =
        await (widget.atualizarPerfil?.call(dados[0], dados[1]) ??
            AuthService.atualizarPerfil(dados[0], dados[1]));

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
    final inicial = nome.isNotEmpty ? nome[0].toUpperCase() : 'U';
    final mediaRecebida =
        double.tryParse(usuario['avaliacaoMedia']?.toString() ?? '') ?? 0;
    final mediaAvaliacao = mediaRecebida.clamp(0, 5).toDouble();
    final totalAvaliacoes =
        int.tryParse(usuario['totalAvaliacoes']?.toString() ?? '') ?? 0;
    final textoMedia = mediaAvaliacao.toStringAsFixed(1).replaceAll('.', ',');
    final textoTotalAvaliacoes = totalAvaliacoes == 0
        ? 'Sem avaliações'
        : totalAvaliacoes == 1
        ? '1 avaliação'
        : '$totalAvaliacoes avaliações';
    final instituicaoCompleta = [
      instituicao,
      if (campus.isNotEmpty) 'Campus $campus',
    ].where((texto) => texto.isNotEmpty).join(' - ');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const BarraSuperiorPadrao(titulo: 'Perfil'),
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
                  CircleAvatar(
                    radius: 42,
                    backgroundColor: const Color(0xFFECDDF5),
                    child: Text(
                      inicial,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
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
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    textoTotalAvaliacoes,
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
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
                onPressed: editarPerfil,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar perfil'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
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
