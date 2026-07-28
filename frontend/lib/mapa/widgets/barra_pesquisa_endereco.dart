import 'dart:async';

import 'package:flutter/material.dart';
import '../services/endereco_service.dart';
import '../models/localizacao_selecionada.dart';

class BarraPesquisaEndereco extends StatefulWidget {
  final ValueChanged<LocalizacaoSelecionada> onSelecionado;
  final EnderecoService? enderecoService;

  const BarraPesquisaEndereco({
    super.key,
    required this.onSelecionado,
    this.enderecoService,
  });

  @override
  State<BarraPesquisaEndereco> createState() => _BarraPesquisaEnderecoState();
}

class _BarraPesquisaEnderecoState extends State<BarraPesquisaEndereco> {
  final TextEditingController _controller = TextEditingController();

  Timer? _debounce;

  late final EnderecoService _enderecoService;

  // Guarda os resultados da pesquisa
  List<LocalizacaoSelecionada> _resultados = [];
  bool _pesquisando = false;
  bool _pesquisaRealizada = false;

  @override
  void initState() {
    super.initState();
    _enderecoService = widget.enderecoService ?? EnderecoService();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pesquisar(String texto) async {
    final textoBusca = texto.trim();

    if (textoBusca.isEmpty) {
      setState(() {
        _resultados = [];
        _pesquisando = false;
        _pesquisaRealizada = false;
      });
      return;
    }

    setState(() {
      _pesquisando = true;
    });

    try {
      final resultados = await _enderecoService.buscarLocalizacoesPorEndereco(
        textoBusca,
      );

      if (!mounted || _controller.text.trim() != textoBusca) {
        return;
      }

      setState(() {
        _resultados = resultados;
        _pesquisaRealizada = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _pesquisando = false;
        });
      }
    }
  }

  void _selecionar(LocalizacaoSelecionada local) {
    _debounce?.cancel();
    _controller.text = local.descricaoCompleta;

    setState(() {
      _resultados = [];
      _pesquisando = false;
      _pesquisaRealizada = false;
    });

    FocusScope.of(context).unfocus();
    widget.onSelecionado(local);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            elevation: 3,
            borderRadius: BorderRadius.circular(12),
            child: TextField(
              controller: _controller,
              keyboardType: TextInputType.streetAddress,
              onChanged: (texto) {
                _debounce?.cancel();

                _debounce = Timer(
                  const Duration(milliseconds: 500),
                  () => _pesquisar(texto),
                );
              },
              decoration: InputDecoration(
                hintText: 'Pesquisar endereço',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _pesquisando
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          if (_resultados.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              constraints: const BoxConstraints(maxHeight: 250),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(blurRadius: 6, color: Colors.black26),
                ],
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _resultados.length,
                itemBuilder: (context, index) {
                  final local = _resultados[index];

                  return ListTile(
                    leading: const Icon(Icons.location_on),
                    title: Text(local.nome ?? local.endereco),
                    subtitle: Text(local.endereco),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _selecionar(local),
                  );
                },
              ),
            ),

          if (_pesquisaRealizada && !_pesquisando && _resultados.isEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(blurRadius: 6, color: Colors.black26),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.search_off, color: Colors.grey),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Nenhum endereço encontrado.\nTente pesquisar por rua, bairro ou cidade.',
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
