import 'dart:async';

import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../models/carona.dart';
import '../models/conversa.dart';
import '../models/notificacao.dart';
import '../services/auth_service.dart';
import '../services/carona_service.dart';
import '../services/mensagem_service.dart';
import '../services/notificacao_service.dart';
import '../widgets/componentes_padrao.dart';
import 'avaliacoes_recebidas.dart';
import 'conversa_detalhe.dart';
import 'detalhes_carona.dart';
import 'historico_caronas.dart';
import 'minhas_caronas.dart';
import 'perfil.dart';
import 'recorrencias.dart';
import 'verificacao_cnh.dart';

class NotificacoesTela extends StatefulWidget {
  final NotificacaoService service;
  final ValueChanged<int>? onLeituraConfirmada;
  final Future<void> Function(Notificacao)? abrirRelacionada;

  const NotificacoesTela({
    super.key,
    this.service = const NotificacaoService(),
    this.onLeituraConfirmada,
    this.abrirRelacionada,
  });

  @override
  State<NotificacoesTela> createState() => _NotificacoesTelaState();
}

class _NotificacoesTelaState extends State<NotificacoesTela>
    with WidgetsBindingObserver {
  final itens = <Notificacao>[];
  bool carregando = true;
  bool consultando = false;
  bool carregandoMais = false;
  bool atualizarDepois = false;
  bool temMais = false;
  int? cursor;
  int? abrindo;
  String? erro;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    MensagemService.versaoNotificacoes.addListener(atualizar);
    carregar(marcarLidas: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    MensagemService.versaoNotificacoes.removeListener(atualizar);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) atualizar();
  }

  void atualizar() {
    if (consultando) {
      atualizarDepois = true;
      return;
    }
    unawaited(carregar());
  }

  Future<void> carregar({bool marcarLidas = false, bool mais = false}) async {
    if (consultando) return;
    consultando = true;
    setState(() {
      carregandoMais = mais;
      erro = null;
    });
    try {
      final resposta = await (marcarLidas
          ? widget.service.abrir()
          : widget.service.listar(antesDe: mais ? cursor : null));
      if (!mounted) return;
      if (resposta['sucesso'] != true ||
          resposta['dados'] is! PaginaNotificacoes) {
        final mensagem =
            resposta['mensagem']?.toString() ??
            'Não foi possível carregar as notificações';
        if (itens.isEmpty) {
          erro = mensagem;
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(mensagem)));
        }
        return;
      }
      final pagina = resposta['dados'] as PaginaNotificacoes;
      if (!mais) itens.clear();
      final ids = itens.map((item) => item.id).toSet();
      itens.addAll(pagina.itens.where((item) => ids.add(item.id)));
      temMais = pagina.temMais;
      cursor = pagina.proximoAntesDe;
      if (marcarLidas) widget.onLeituraConfirmada?.call(pagina.totalNaoLidas);
    } catch (_) {
      if (mounted) {
        erro = 'Não foi possível carregar as notificações. Tente novamente';
      }
    } finally {
      consultando = false;
      if (mounted) {
        setState(() {
          carregando = false;
          carregandoMais = false;
        });
        if (atualizarDepois) {
          atualizarDepois = false;
          atualizar();
        }
      }
    }
  }

  Future<void> abrirNotificacao(Notificacao item) async {
    if (abrindo != null) return;
    setState(() => abrindo = item.id);
    try {
      if (widget.abrirRelacionada != null) {
        await widget.abrirRelacionada!(item);
        return;
      }
      Widget? tela;
      final refs = item.referencias;
      final id = int.tryParse(
        AuthService.usuarioLogado?['id']?.toString() ?? '',
      );
      switch (refs['tela']) {
        case 'CONVERSA':
          final solicitacao = int.tryParse(
            refs['idSolicitacao']?.toString() ?? '',
          );
          if (solicitacao == null || solicitacao <= 0) {
            throw const FormatException();
          }
          final resposta = await MensagemService.obterConversa(solicitacao);
          if (resposta['sucesso'] != true || resposta['dados'] is! Conversa) {
            throw StateError('Conversa indisponivel');
          }
          tela = ConversaDetalheTela(conversa: resposta['dados'] as Conversa);
        case 'CARONA':
          final carona = int.tryParse(refs['idCarona']?.toString() ?? '');
          if (carona == null || carona <= 0) throw const FormatException();
          final resposta = await CaronaService.buscarDetalhesCarona(carona);
          if (resposta['sucesso'] != true || resposta['dados'] is! Carona) {
            throw StateError('Carona indisponivel');
          }
          tela = DetalhesCaronaTela(carona: resposta['dados'] as Carona);
        case 'SOLICITACOES':
          tela = MinhasCaronasTela(
            abaInicial: refs['aba'] == 'RECEBIDAS' ? 0 : 1,
          );
        case 'HISTORICO':
          tela = const HistoricoCaronasTela();
        case 'CNH':
          tela = const VerificacaoCnhTela();
        case 'RECORRENCIAS':
          tela = const RecorrenciasTela();
        case 'PERFIL':
          tela = const PerfilTela();
        case 'AVALIACOES':
          if (id == null || id <= 0) throw const FormatException();
          tela = AvaliacoesRecebidasTela(
            idUsuario: id,
            nomeUsuario: AuthService.usuarioLogado?['nome']?.toString() ?? '',
          );
        default:
          throw const FormatException();
      }
      if (!mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => tela!),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível abrir esta atualização. Tente novamente',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => abrindo = null);
    }
  }

  IconData icone(String tipo) => switch (tipo) {
    'MENSAGEM' => Icons.chat_bubble_outline,
    'SOLICITACAO' => Icons.person_add_alt,
    'CARONA' => Icons.directions_car_outlined,
    'PAGAMENTO' => Icons.payments_outlined,
    'AVALIACAO' => Icons.star_outline,
    'CNH' => Icons.badge_outlined,
    'RECORRENCIA' => Icons.event_repeat,
    'PERFIL' => Icons.person_outline,
    _ => Icons.notifications_none,
  };

  String horario(DateTime data) =>
      '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year} · ${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: const BarraSuperiorPadrao(titulo: 'Notificações'),
    body: SafeArea(
      child: RefreshIndicator(
        onRefresh: () => carregar(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            if (carregando)
              const EstadoConteudoPadrao(carregando: true)
            else if (erro != null)
              EstadoConteudoPadrao(
                mensagem: erro!,
                icone: Icons.cloud_off_outlined,
                textoBotao: 'Tentar novamente',
                onPressed: () => carregar(marcarLidas: true),
              )
            else if (itens.isEmpty)
              const EstadoConteudoPadrao(
                mensagem: 'Nenhuma notificação',
                icone: Icons.notifications_none,
              )
            else ...[
              for (final item in itens) ...[
                ListTile(
                  key: ValueKey('notificacao_${item.id}'),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  tileColor: item.lidaEm == null
                      ? AppColors.primary.withAlpha(12)
                      : null,
                  leading: Icon(icone(item.tipo), color: AppColors.primary),
                  title: Text(
                    item.titulo,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        item.descricao,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        horario(item.criadoEm),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  trailing: SizedBox(
                    width: 24,
                    height: 24,
                    child: abrindo == item.id
                        ? const CircularProgressIndicator(strokeWidth: 2)
                        : const Icon(Icons.chevron_right),
                  ),
                  onTap: () => abrirNotificacao(item),
                ),
                const Divider(height: 1, indent: 24, endIndent: 24),
              ],
              if (temMais)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: carregandoMais
                      ? const Center(child: CircularProgressIndicator())
                      : TextButton.icon(
                          onPressed: () => carregar(mais: true),
                          icon: const Icon(Icons.history),
                          label: const Text('Carregar anteriores'),
                        ),
                ),
            ],
          ],
        ),
      ),
    ),
  );
}
