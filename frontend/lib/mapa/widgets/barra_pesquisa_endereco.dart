import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../models/localizacao_selecionada.dart';
import '../services/endereco_service.dart';

class BarraPesquisaEndereco extends StatefulWidget {
  final ValueChanged<LocalizacaoSelecionada> onSelecionado;
  final EnderecoService? enderecoService;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  final String label;
  final IconData icone;
  final EdgeInsetsGeometry padding;
  final double elevacao;
  final double borderRadius;
  final bool usarLabelComoHint;

  // Contexto usado para priorizar resultados próximos.
  final double? latitudeReferencia;
  final double? longitudeReferencia;
  final String? cidadeReferencia;
  final String? estadoReferencia;

  const BarraPesquisaEndereco({
    super.key,
    required this.onSelecionado,
    this.enderecoService,
    this.controller,
    this.onChanged,
    this.label = 'Pesquisar endereço',
    this.icone = Icons.search,
    this.padding = const EdgeInsets.all(12),
    this.elevacao = 3,
    this.borderRadius = 12,
    this.usarLabelComoHint = true,
    this.latitudeReferencia,
    this.longitudeReferencia,
    this.cidadeReferencia,
    this.estadoReferencia,
  });

  @override
  State<BarraPesquisaEndereco> createState() =>
      _BarraPesquisaEnderecoState();
}

class _BarraPesquisaEnderecoState
    extends State<BarraPesquisaEndereco> {
  late final TextEditingController _controller;
  late final bool _controllerInterno;
  late final EnderecoService _enderecoService;

  Timer? _debounce;
  int _numeroBusca = 0;

  List<LocalizacaoSelecionada> _resultados = [];

  bool _pesquisando = false;
  bool _pesquisaRealizada = false;

  @override
  void initState() {
    super.initState();

    _controllerInterno = widget.controller == null;

    _controller =
        widget.controller ?? TextEditingController();

    _enderecoService =
        widget.enderecoService ?? EnderecoService();
  }

  @override
  void dispose() {
    _debounce?.cancel();

    if (_controllerInterno) {
      _controller.dispose();
    }

    super.dispose();
  }

  void _aoDigitar(String texto) {
    widget.onChanged?.call(texto);

    _debounce?.cancel();

    final textoBusca = texto.trim();

    if (textoBusca.length < 3) {
      _numeroBusca++;

      setState(() {
        _resultados = [];
        _pesquisando = false;
        _pesquisaRealizada = false;
      });

      return;
    }

    _debounce = Timer(
      const Duration(milliseconds: 500),
          () => _pesquisar(textoBusca),
    );
  }

  Future<void> _pesquisar(String texto) async {
    final textoBusca = texto.trim();

    if (textoBusca.length < 3) {
      return;
    }

    final numeroBusca = ++_numeroBusca;

    setState(() {
      _pesquisando = true;
      _pesquisaRealizada = false;
    });

    final resultados =
    await _enderecoService.buscarLocalizacoesPorEndereco(
      textoBusca,
      latitudeReferencia: widget.latitudeReferencia,
      longitudeReferencia: widget.longitudeReferencia,
      cidadeReferencia: widget.cidadeReferencia,
      estadoReferencia: widget.estadoReferencia,
    );

    if (!mounted ||
        numeroBusca != _numeroBusca ||
        _controller.text.trim() != textoBusca) {
      return;
    }

    setState(() {
      _resultados = resultados;
      _pesquisando = false;
      _pesquisaRealizada = true;
    });
  }

  void _selecionar(
      LocalizacaoSelecionada local,
      ) {
    _debounce?.cancel();

    _numeroBusca++;

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
      padding: widget.padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            elevation: widget.elevacao,
            borderRadius: BorderRadius.circular(
              widget.borderRadius,
            ),
            child: TextField(
              controller: _controller,
              keyboardType: TextInputType.streetAddress,
              textInputAction: TextInputAction.search,
              onChanged: _aoDigitar,
              onSubmitted: (texto) {
                _debounce?.cancel();
                _pesquisar(texto);
              },
              style: const TextStyle(
                color: AppColors.text,
              ),
              decoration: InputDecoration(
                labelText: widget.usarLabelComoHint
                    ? null
                    : widget.label,
                hintText: widget.usarLabelComoHint
                    ? widget.label
                    : null,
                prefixIcon: Icon(
                  widget.icone,
                  color: AppColors.primary,
                ),
                suffixIcon: _pesquisando
                    ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius:
                  BorderRadius.circular(
                    widget.borderRadius,
                  ),
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
                borderRadius:
                BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 6,
                    color: Colors.black26,
                  ),
                ],
              ),
              child: ListView.builder(
                primary: false,
                shrinkWrap: true,
                itemCount: _resultados.length,
                itemBuilder: (context, index) {
                  final local =
                  _resultados[index];

                  final nome =
                  local.nome?.trim();

                  return ListTile(
                    leading: const Icon(
                      Icons.location_on,
                    ),
                    title: Text(
                      nome != null &&
                          nome.isNotEmpty
                          ? nome
                          : local.endereco,
                    ),
                    subtitle: nome != null &&
                        nome.isNotEmpty
                        ? Text(local.endereco)
                        : null,
                    trailing: const Icon(
                      Icons.chevron_right,
                    ),
                    onTap: () =>
                        _selecionar(local),
                  );
                },
              ),
            ),

          if (_pesquisaRealizada &&
              !_pesquisando &&
              _resultados.isEmpty)
            Container(
              margin:
              const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 6,
                    color: Colors.black26,
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.search_off,
                    color: Colors.grey,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Nenhum endereço encontrado.\n'
                          'Tente pesquisar por rua, bairro ou cidade.',
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