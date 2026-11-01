import 'package:flutter/material.dart';

import '../models/verificacao_cnh.dart';
import 'foto_perfil.dart';
import 'visual_buscaeu.dart';

class ConteudoPerfilBuscaEu extends StatelessWidget {
  final Map<String, dynamic> usuario;
  final bool carregando, enviandoFoto;
  final double media;
  final int totalAvaliacoes;
  final String? erro, erroAvaliacoes;
  final String tipoPerfil, situacaoPerfil;
  final IconData iconeSituacao;
  final Color corSituacao;
  final VoidCallback onFoto, onEditar, onVeiculo, onCnh, onAvaliacoes;
  final VoidCallback onHistorico, onRecorrencias, onSair, onRecarregar;

  const ConteudoPerfilBuscaEu({
    super.key,
    required this.usuario,
    required this.carregando,
    required this.enviandoFoto,
    required this.media,
    required this.totalAvaliacoes,
    required this.erro,
    required this.erroAvaliacoes,
    required this.tipoPerfil,
    required this.situacaoPerfil,
    required this.iconeSituacao,
    required this.corSituacao,
    required this.onFoto,
    required this.onEditar,
    required this.onVeiculo,
    required this.onCnh,
    required this.onAvaliacoes,
    required this.onHistorico,
    required this.onRecorrencias,
    required this.onSair,
    required this.onRecarregar,
  });

  @override
  Widget build(BuildContext context) {
    final nome = usuario['nome']?.toString().trim() ?? '';
    final email = usuario['email']?.toString().trim() ?? '';
    final instituicao = usuario['instituicao']?.toString().trim() ?? '';
    final campus = usuario['campus']?.toString().trim() ?? '';
    final instituicaoCompleta = [
      instituicao,
      if (campus.isNotEmpty) 'Campus $campus',
    ].where((texto) => texto.isNotEmpty).join(' - ');
    final cnh = VerificacaoCnh.fromPerfil(usuario);
    final veiculo = usuario['veiculo'] is Map
        ? usuario['veiculo'] as Map
        : null;
    final nota = media.clamp(0, 5).toStringAsFixed(1).replaceAll('.', ',');
    final avaliacoes = totalAvaliacoes == 0
        ? 'Sem avaliações'
        : totalAvaliacoes == 1
        ? '1 avaliação'
        : '$totalAvaliacoes avaliações';
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      children: [
        if (carregando) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: 20),
        ],
        Center(
          child: FotoPerfil(
            nome: nome,
            urlFoto: usuario['fotoPerfil']?.toString().trim(),
            carregando: enviandoFoto,
            onTap: carregando ? null : onFoto,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          nome.isEmpty ? 'Usuário' : nome,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w700,
            color: VisualBuscaEu.texto,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          instituicaoCompleta.isEmpty
              ? 'Instituição não informada'
              : instituicaoCompleta,
          textAlign: TextAlign.center,
          style: VisualBuscaEu.descricao,
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            SeloBuscaEu(texto: tipoPerfil, cor: VisualBuscaEu.secundario),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(iconeSituacao, color: corSituacao, size: 16),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    situacaoPerfil,
                    style: TextStyle(fontSize: 12, color: corSituacao),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: onAvaliacoes,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFE7A524),
                      size: 22,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '$nota / 5',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: VisualBuscaEu.secundario,
                    ),
                  ],
                ),
                Text(
                  erroAvaliacoes ?? avaliacoes,
                  textAlign: TextAlign.center,
                  style: VisualBuscaEu.descricao,
                ),
              ],
            ),
          ),
        ),
        if (erro != null)
          TextButton.icon(
            onPressed: onRecarregar,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar atualizar novamente'),
          ),
        const SizedBox(height: 20),
        const Text('Meu veículo', style: VisualBuscaEu.titulo),
        const SizedBox(height: 10),
        CartaoBuscaEu(
          padding: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.directions_car_outlined),
            title: Text(veiculo?['modelo']?.toString() ?? 'Cadastrar veículo'),
            subtitle: Text(
              veiculo == null
                  ? 'Necessário para oferecer caronas'
                  : '${veiculo['cor']} • ${veiculo['placa']}',
            ),
            trailing: Icon(veiculo == null ? Icons.add : Icons.chevron_right),
            onTap: carregando ? null : onVeiculo,
          ),
        ),
        const SizedBox(height: 20),
        const Text('Habilitação', style: VisualBuscaEu.titulo),
        const SizedBox(height: 10),
        CartaoBuscaEu(
          padding: EdgeInsets.zero,
          child: ListTile(
            leading: Icon(
              Icons.badge_outlined,
              color: cnh.permiteOferecerCarona()
                  ? const Color(0xFF16764B)
                  : VisualBuscaEu.secundario,
            ),
            title: Text(cnh.textoStatus),
            subtitle: Text(
              cnh.permiteOferecerCarona()
                  ? 'Categoria ${cnh.categoria} · Válida até ${cnh.validadeFormatada}'
                  : 'Necessária para oferecer caronas',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: carregando ? null : onCnh,
          ),
        ),
        const SizedBox(height: 20),
        const Text('Sua atividade', style: VisualBuscaEu.titulo),
        const SizedBox(height: 10),
        CartaoBuscaEu(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _atalho(Icons.star_outline, 'Avaliações recebidas', onAvaliacoes),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _atalho(
                Icons.history,
                'Histórico de caronas',
                onHistorico,
                'Como motorista e passageiro',
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _atalho(
                Icons.repeat,
                'Recorrências de caronas',
                onRecorrencias,
                'Editar, pausar ou retomar suas programações',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text('Dados da conta', style: VisualBuscaEu.titulo),
        const SizedBox(height: 10),
        CartaoBuscaEu(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Nome'),
                subtitle: Text(nome.isEmpty ? 'Não informado' : nome),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.email_outlined),
                title: const Text('E-mail'),
                subtitle: Text(email.isEmpty ? 'Não informado' : email),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: carregando ? null : onEditar,
          icon: const Icon(Icons.edit_outlined, size: 20),
          label: const Text('Editar perfil'),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: onSair,
          icon: const Icon(Icons.logout, size: 20),
          label: const Text('Sair'),
          style: TextButton.styleFrom(foregroundColor: const Color(0xFFBE303B)),
        ),
      ],
    );
  }

  Widget _atalho(
    IconData icone,
    String titulo,
    VoidCallback onTap, [
    String? subtitulo,
  ]) => ListTile(
    leading: Icon(icone),
    title: Text(titulo),
    subtitle: subtitulo == null ? null : Text(subtitulo),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}
