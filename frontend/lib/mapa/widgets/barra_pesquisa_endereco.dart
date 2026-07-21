import 'package:flutter/material.dart';
import '../services/endereco_service.dart';
import '../models/localizacao_selecionada.dart';

class BarraPesquisaEndereco extends StatefulWidget {
  const BarraPesquisaEndereco({super.key});

  @override
  State<BarraPesquisaEndereco> createState() =>
      _BarraPesquisaEnderecoState();
}

class _BarraPesquisaEnderecoState extends State<BarraPesquisaEndereco> {

  final TextEditingController _controller = TextEditingController();

  final EnderecoService _enderecoService = EnderecoService();

  // Guarda os resultados da pesquisa
  List<LocalizacaoSelecionada> _resultados = [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pesquisar(String texto) async {
    final resultados =
    await _enderecoService.buscarLocalizacoesPorEndereco(texto);

    setState(() {
      _resultados = resultados;
    });
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
              constraints: const BoxConstraints(
                maxHeight: 250,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 6,
                    color: Colors.black26,
                  ),
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
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}