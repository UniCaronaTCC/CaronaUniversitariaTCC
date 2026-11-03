import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../models/campus_destino.dart';
import '../services/catalogo_cidades_service.dart';

class SelecaoCidade {
  final CidadeCampus? cidade;

  const SelecaoCidade(this.cidade);
}

class SeletorCidade extends StatefulWidget {
  final CidadeCampus? cidadeAtual;
  final CatalogoCidadesService catalogoService;

  const SeletorCidade({
    super.key,
    this.cidadeAtual,
    this.catalogoService = const CatalogoCidadesService(),
  });

  @override
  State<SeletorCidade> createState() => _SeletorCidadeState();
}

class _SeletorCidadeState extends State<SeletorCidade> {
  final _pesquisa = TextEditingController();
  List<CidadeCampus> _cidades = [];
  String _uf = '';
  bool _carregando = true;
  bool _falhou = false;

  @override
  void initState() {
    super.initState();
    _uf = widget.cidadeAtual?.uf ?? '';
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _falhou = false;
    });
    try {
      final cidades = await widget.catalogoService.listar();
      if (mounted) setState(() => _cidades = cidades);
    } catch (_) {
      if (mounted) setState(() => _falhou = true);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  void dispose() {
    _pesquisa.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final termo = normalizarDestino(_pesquisa.text);
    final cidades = _cidades.where((cidade) {
      return (_uf.isEmpty || cidade.uf == _uf) &&
          normalizarDestino('${cidade.cidade} ${cidade.uf}').contains(termo);
    }).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FractionallySizedBox(
        heightFactor: 0.88,
        child: SafeArea(
          top: false,
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                sliver: SliverList.list(
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Selecionar cidade',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Fechar cidades',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const ValueKey('pesquisa-cidade'),
                      controller: _pesquisa,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Pesquisar cidade',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _pesquisa.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Limpar pesquisa de cidade',
                                onPressed: () => setState(_pesquisa.clear),
                                icon: const Icon(Icons.close),
                              ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: const ValueKey('estado-cidades'),
                      initialValue: _uf,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Estado'),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('Todos os estados'),
                        ),
                        for (final estado in CidadeCampus.estados.entries)
                          DropdownMenuItem(
                            value: estado.key,
                            child: Text(
                              '${estado.key} - ${estado.value}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (uf) => setState(() => _uf = uf ?? ''),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.my_location,
                        color: AppColors.primary,
                      ),
                      title: const Text('Usar localização atual'),
                      onTap: () =>
                          Navigator.pop(context, const SelecaoCidade(null)),
                    ),
                    const Divider(),
                    if (_carregando) const LinearProgressIndicator(),
                    if (_falhou) ...[
                      const Text('Não foi possível carregar as cidades.'),
                      TextButton.icon(
                        onPressed: _carregar,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tentar novamente'),
                      ),
                    ],
                    if (!_carregando && !_falhou && cidades.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('Nenhuma cidade encontrada.'),
                      ),
                  ],
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                sliver: SliverList.builder(
                  itemCount: cidades.length,
                  itemBuilder: (context, indice) {
                    final cidade = cidades[indice];
                    return ListTile(
                      key: ValueKey('cidade-${cidade.cidade}-${cidade.uf}'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(cidade.cidade),
                      subtitle: Text(cidade.uf),
                      trailing: widget.cidadeAtual?.mesmaCidade(cidade) == true
                          ? const Icon(Icons.check, color: AppColors.primary)
                          : null,
                      onTap: () =>
                          Navigator.pop(context, SelecaoCidade(cidade)),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
