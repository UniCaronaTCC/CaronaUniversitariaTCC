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

  late final EnderecoService _enderecoService;

  // Guarda os resultados da pesquisa
  List<LocalizacaoSelecionada> _resultados = [];

  @override
  void initState() {
    super.initState();
    _enderecoService = widget.enderecoService ?? EnderecoService();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pesquisar(String texto) async {
    final textoBusca = texto.trim();

    if (textoBusca.isEmpty) {
      setState(() {
        _resultados = [];
      });
      return;
    }

    final resultados = await _enderecoService.buscarLocalizacoesPorEndereco(
      textoBusca,
    );

    if (!mounted || _controller.text.trim() != textoBusca) {
      return;
    }

    setState(() {
      _resultados = resultados;
    });
  }

  void _selecionar(LocalizacaoSelecionada local) {
    _controller.text = local.descricaoCompleta;

    setState(() {
      _resultados = [];
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
              onChanged: _pesquisar,
              decoration: InputDecoration(
                hintText: 'Pesquisar endereço',
                prefixIcon: const Icon(Icons.search),
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
        ],
      ),
    );
  }
}
