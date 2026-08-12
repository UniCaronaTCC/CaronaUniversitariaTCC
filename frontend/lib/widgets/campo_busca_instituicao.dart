import 'dart:async';

import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../mapa/services/endereco_service.dart';
import '../mapa/services/localizacao_service.dart';
import '../models/instituicao.dart';
import '../services/instituicao_service.dart';

typedef BuscarInstituicoes = Future<List<Instituicao>> Function(String termo);

class CampoBuscaInstituicao extends StatefulWidget {
  final String valorInicial;
  final BuscarInstituicoes? buscarInstituicoes;
  final ValueChanged<Instituicao?> onChanged;

  const CampoBuscaInstituicao({
    super.key,
    required this.valorInicial,
    required this.onChanged,
    this.buscarInstituicoes,
  });

  @override
  State<CampoBuscaInstituicao> createState() => _CampoBuscaInstituicaoState();
}

class _CampoBuscaInstituicaoState extends State<CampoBuscaInstituicao> {
  late final TextEditingController controller;
  Timer? debounce;
  List<Instituicao> resultados = [];
  bool buscando = false;
  int numeroBusca = 0;
  String? cidadeUsuario;
  String? ufUsuario;
  double? latitudeUsuario;
  double? longitudeUsuario;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.valorInicial);

    if (widget.buscarInstituicoes == null) {
      carregarLocalizacao();
    }
  }

  Future<void> carregarLocalizacao() async {
    try {
      final posicao = await LocalizacaoService().obterLocalizacaoAtual();
      final localizacao = await EnderecoService()
          .buscarLocalizacaoPorCoordenadas(posicao.latitude, posicao.longitude);

      latitudeUsuario = posicao.latitude;
      longitudeUsuario = posicao.longitude;
      cidadeUsuario = localizacao?.cidade;

      final estado = localizacao?.estado?.trim() ?? '';
      if (estado.length == 2) {
        ufUsuario = estado;
      }
    } catch (_) {
      // A busca continua funcionando mesmo sem permissão de localização.
    }
  }

  @override
  void dispose() {
    debounce?.cancel();
    controller.dispose();
    super.dispose();
  }

  void aoDigitar(String texto) {
    debounce?.cancel();
    numeroBusca++;
    widget.onChanged(null);

    if (texto.trim().length < 2) {
      setState(() {
        resultados = [];
        buscando = false;
      });
      return;
    }

    debounce = Timer(const Duration(milliseconds: 400), () => buscar(texto));
  }

  Future<void> buscar(String texto) async {
    final buscaAtual = ++numeroBusca;

    setState(() => buscando = true);

    final encontrados =
        await (widget.buscarInstituicoes?.call(texto) ??
            InstituicaoService.buscar(
              texto,
              cidade: cidadeUsuario,
              uf: ufUsuario,
              latitude: latitudeUsuario,
              longitude: longitudeUsuario,
            ));

    if (!mounted || buscaAtual != numeroBusca) {
      return;
    }

    setState(() {
      resultados = encontrados;
      buscando = false;
    });
  }

  void selecionar(Instituicao instituicao) {
    debounce?.cancel();
    numeroBusca++;
    controller.text = instituicao.nome;

    setState(() {
      resultados = [];
      buscando = false;
    });

    widget.onChanged(instituicao);
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: controller,
          onChanged: aoDigitar,
          decoration: InputDecoration(
            labelText: 'Instituição',
            helperText: 'Digite e selecione uma opção da lista',
            suffixIcon: buscando
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.search),
            enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: AppColors.primary),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: AppColors.primary, width: 3),
            ),
          ),
        ),
        if (resultados.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: resultados.map((instituicao) {
                  final sigla = instituicao.sigla?.trim() ?? '';

                  return ListTile(
                    dense: true,
                    title: Text(
                      sigla.isEmpty
                          ? instituicao.nome
                          : '${instituicao.nome} ($sigla)',
                    ),
                    subtitle: Text(
                      'Campus ${instituicao.campus} - '
                      '${instituicao.municipio}/${instituicao.uf}',
                    ),
                    onTap: () => selecionar(instituicao),
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }
}
