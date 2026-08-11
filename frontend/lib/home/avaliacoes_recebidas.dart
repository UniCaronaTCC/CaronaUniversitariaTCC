import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../navigation/navegacao_principal.dart';
import '../services/avaliacao_service.dart';
import '../utils/formatador_data.dart';
import '../widgets/barra_navegacao_home.dart';
import '../widgets/componentes_padrao.dart';

typedef CarregarAvaliacoes =
    Future<Map<String, dynamic>> Function(int idUsuario, int pagina);

class AvaliacoesRecebidasTela extends StatefulWidget {
  final int idUsuario;
  final String nomeUsuario;
  final CarregarAvaliacoes? carregarAvaliacoes;

  const AvaliacoesRecebidasTela({
    super.key,
    required this.idUsuario,
    required this.nomeUsuario,
    this.carregarAvaliacoes,
  });

  @override
  State<AvaliacoesRecebidasTela> createState() =>
      _AvaliacoesRecebidasTelaState();
}

class _AvaliacoesRecebidasTelaState extends State<AvaliacoesRecebidasTela> {
  final List<Map<String, dynamic>> avaliacoes = [];
  bool carregando = true;
  bool carregandoMais = false;
  String? mensagemErro;
  double media = 0;
  int total = 0;
  int pagina = 1;
  int totalPaginas = 0;

  @override
  void initState() {
    super.initState();
    carregarDados();
  }

  Future<void> carregarDados({bool proximaPagina = false}) async {
    final paginaBuscada = proximaPagina ? pagina + 1 : 1;

    setState(() {
      if (proximaPagina) {
        carregandoMais = true;
      } else {
        carregando = true;
        mensagemErro = null;
      }
    });

    final resultado =
        await (widget.carregarAvaliacoes?.call(
              widget.idUsuario,
              paginaBuscada,
            ) ??
            AvaliacaoService.listarRecebidas(
              widget.idUsuario,
              pagina: paginaBuscada,
            ));

    if (!mounted) {
      return;
    }

    if (resultado['sucesso'] != true || resultado['dados'] is! Map) {
      setState(() {
        carregando = false;
        carregandoMais = false;
        mensagemErro = resultado['mensagem']?.toString();
      });
      return;
    }

    final dados = Map<String, dynamic>.from(resultado['dados']);
    final recebidas = dados['avaliacoes'] is List
        ? List<Map<String, dynamic>>.from(
            (dados['avaliacoes'] as List).whereType<Map>().map(
              (item) => Map<String, dynamic>.from(item),
            ),
          )
        : <Map<String, dynamic>>[];

    setState(() {
      if (!proximaPagina) {
        avaliacoes.clear();
      }

      avaliacoes.addAll(recebidas);
      media = double.tryParse(dados['media']?.toString() ?? '') ?? 0;
      total = int.tryParse(dados['total']?.toString() ?? '') ?? 0;
      pagina = int.tryParse(dados['pagina']?.toString() ?? '') ?? paginaBuscada;
      totalPaginas = int.tryParse(dados['totalPaginas']?.toString() ?? '') ?? 0;
      carregando = false;
      carregandoMais = false;
      mensagemErro = null;
    });
  }

  String formatarData(dynamic dataRecebida) {
    final data = DateTime.tryParse(dataRecebida?.toString() ?? '');

    return data == null ? '' : FormatadorData.completa(data.toLocal());
  }

  Widget itemAvaliacao(Map<String, dynamic> avaliacao) {
    final avaliador = avaliacao['avaliador'] is Map
        ? Map<String, dynamic>.from(avaliacao['avaliador'])
        : <String, dynamic>{};
    final nome = avaliador['nome']?.toString() ?? 'Usuário';
    final nota = int.tryParse(avaliacao['nota']?.toString() ?? '') ?? 0;
    final comentario = avaliacao['comentario']?.toString().trim() ?? '';
    final data = formatarData(avaliacao['criadoEm']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                nome,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (data.isNotEmpty)
              Text(data, style: const TextStyle(color: Colors.black54)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: List.generate(
            5,
            (indice) => Icon(
              indice < nota ? Icons.star : Icons.star_border,
              color: AppColors.primary,
              size: 20,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          comentario.isNotEmpty ? comentario : 'Sem comentário',
          style: const TextStyle(color: Colors.black87),
        ),
        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final textoMedia = media.toStringAsFixed(1).replaceAll('.', ',');
    final textoTotal = total == 1 ? '1 avaliação' : '$total avaliações';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const BarraSuperiorPadrao(titulo: 'Avaliações recebidas'),
      bottomNavigationBar: BarraNavegacaoHome(
        currentIndex: 3,
        onTap: (indice) =>
            NavegacaoPrincipal.selecionar(context, indice, indiceAtual: 3),
      ),
      body: SafeArea(
        child: carregando
            ? const EstadoConteudoPadrao(
                carregando: true,
                mensagem: 'Carregando avaliações...',
              )
            : mensagemErro != null
            ? EstadoConteudoPadrao(
                icone: Icons.error_outline,
                mensagem: mensagemErro,
                textoBotao: 'Tentar novamente',
                onPressed: carregarDados,
              )
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    widget.nomeUsuario,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        '$textoMedia / 5  ·  $textoTotal',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  if (avaliacoes.isEmpty)
                    const EstadoConteudoPadrao(
                      icone: Icons.star_border,
                      mensagem: 'Nenhuma avaliação recebida',
                    )
                  else
                    ...avaliacoes.map(itemAvaliacao),
                  if (pagina < totalPaginas)
                    Center(
                      child: TextButton(
                        onPressed: carregandoMais
                            ? null
                            : () => carregarDados(proximaPagina: true),
                        child: Text(
                          carregandoMais ? 'Carregando...' : 'Ver mais',
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
