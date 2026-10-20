import 'dart:async';

import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../mapa/models/localizacao_selecionada.dart';
import '../mapa/services/endereco_service.dart';
import '../models/campus_destino.dart';
import '../services/campus_destino_service.dart';

class CampoDestinoCampus extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<LocalizacaoSelecionada> onSelecionado;
  final ValueChanged<String>? onChanged;
  final LocalizacaoSelecionada? referenciaInicial;
  final CampusDestinoService campusService;
  final EnderecoService? enderecoService;
  final bool mostrarAoAbrir;

  const CampoDestinoCampus({
    super.key,
    required this.controller,
    required this.onSelecionado,
    this.onChanged,
    this.referenciaInicial,
    this.campusService = const CampusDestinoService(),
    this.enderecoService,
    this.mostrarAoAbrir = false,
  });

  @override
  State<CampoDestinoCampus> createState() => _CampoDestinoCampusState();
}

class _CampoDestinoCampusState extends State<CampoDestinoCampus> {
  final _foco = FocusNode();
  late final EnderecoService _enderecos;
  CidadeCampus? _cidade;
  List<CampusDestino> _campi = [];
  List<LocalizacaoSelecionada> _locais = [];
  String _filtro = '';
  String? _erroCampi;
  CampusDestino? _confirmandoCampus;
  Timer? _debounce;
  int _consultaCampi = 0;
  int _consultaEndereco = 0;
  bool _carregandoCampi = false;
  bool _buscandoEndereco = false;
  bool _pesquisouEndereco = false;
  bool _iniciado = false;
  bool _visivel = false;
  bool _cidadeManual = false;

  @override
  void initState() {
    super.initState();
    _enderecos = widget.enderecoService ?? EnderecoService();
    _cidade = CidadeCampus.deLocalizacao(widget.referenciaInicial);
    _visivel = widget.mostrarAoAbrir;
    widget.controller.addListener(_textoAlterado);
    _foco.addListener(_focoAlterado);
    if (_visivel) _iniciar();
  }

  @override
  void didUpdateWidget(CampoDestinoCampus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_textoAlterado);
      widget.controller.addListener(_textoAlterado);
      _textoAlterado();
    }
    final nova = CidadeCampus.deLocalizacao(widget.referenciaInicial);
    if (!_cidadeManual &&
        nova != null &&
        (_cidade == null || !_cidade!.mesmaCidade(nova))) {
      if (_iniciado) {
        _carregarCampi(nova);
      } else {
        _cidade = nova;
      }
    }
  }

  void _focoAlterado() {
    setState(() => _visivel = _foco.hasFocus || widget.mostrarAoAbrir);
    if (_foco.hasFocus && !_iniciado) _iniciar();
  }

  void _textoAlterado() {
    _debounce?.cancel();
    _consultaEndereco++;
    setState(() {
      _filtro = widget.controller.text;
      _locais = [];
      _confirmandoCampus = null;
      _buscandoEndereco = false;
      _pesquisouEndereco = false;
    });
  }

  Future<void> _iniciar() async {
    _iniciado = true;
    if (_cidade != null) return _carregarCampi(_cidade!);
    final consulta = ++_consultaCampi;
    setState(() => _carregandoCampi = true);
    CidadeCampus? cidade;
    try {
      cidade = await widget.campusService.identificarCidade();
    } catch (_) {
      cidade = null;
    }
    if (!mounted || consulta != _consultaCampi) return;
    if (cidade == null) {
      setState(() => _carregandoCampi = false);
      return;
    }
    await _carregarCampi(cidade);
  }

  Future<void> _carregarCampi(CidadeCampus cidade) async {
    final consulta = ++_consultaCampi;
    final mesmaCidade = _cidade?.mesmaCidade(cidade) == true;
    _debounce?.cancel();
    _consultaEndereco++;
    setState(() {
      _cidade = cidade;
      if (!mesmaCidade) _campi = [];
      _locais = [];
      _confirmandoCampus = null;
      _buscandoEndereco = false;
      _pesquisouEndereco = false;
      _carregandoCampi = true;
      _erroCampi = null;
    });
    try {
      final campi = await widget.campusService.listar(cidade);
      if (!mounted || consulta != _consultaCampi) return;
      setState(() => _campi = campi);
    } catch (_) {
      if (!mounted || consulta != _consultaCampi) return;
      setState(() => _erroCampi = 'Não foi possível carregar as faculdades.');
    } finally {
      if (mounted && consulta == _consultaCampi) {
        setState(() => _carregandoCampi = false);
      }
    }
    if (mounted && consulta == _consultaCampi && _filtro.trim().length >= 3) {
      _agendarEndereco(_filtro);
    }
  }

  void _aoDigitar(String texto) {
    widget.onChanged?.call(texto);
    _agendarEndereco(texto);
  }

  void _agendarEndereco(String texto) {
    _debounce?.cancel();
    if (texto.trim().length < 3) return;
    _debounce = Timer(
      const Duration(milliseconds: 500),
      () => _buscarEndereco(texto),
    );
  }

  Future<void> _buscarEndereco(String texto) async {
    if (texto.trim().length < 3) return;
    final consulta = ++_consultaEndereco;
    setState(() {
      _buscandoEndereco = true;
      _pesquisouEndereco = false;
    });
    try {
      final usarReferencia =
          _cidade != null &&
          CidadeCampus.deLocalizacao(
                widget.referenciaInicial,
              )?.mesmaCidade(_cidade!) ==
              true;
      final locais = await _enderecos.buscarLocalizacoesPorEndereco(
        texto,
        cidadeReferencia: _cidade?.cidade,
        estadoReferencia: CidadeCampus.estados[_cidade?.uf],
        latitudeReferencia: usarReferencia
            ? widget.referenciaInicial?.ponto.latitude
            : null,
        longitudeReferencia: usarReferencia
            ? widget.referenciaInicial?.ponto.longitude
            : null,
      );
      if (!mounted || consulta != _consultaEndereco) return;
      setState(() {
        _locais = locais.where((local) {
          final campus = _confirmandoCampus;
          if (campus == null) return true;
          return local.pontoEspecifico &&
              normalizarDestino(local.cidade ?? '') ==
                  normalizarDestino(campus.cidade.cidade) &&
              CidadeCampus.normalizarUf(local.estado) == campus.cidade.uf;
        }).toList();
      });
    } catch (_) {
      if (!mounted || consulta != _consultaEndereco) return;
      setState(() => _locais = []);
    } finally {
      if (mounted && consulta == _consultaEndereco) {
        setState(() {
          _buscandoEndereco = false;
          _pesquisouEndereco = true;
        });
      }
    }
  }

  void _selecionar(LocalizacaoSelecionada local) {
    _debounce?.cancel();
    _consultaEndereco++;
    widget.controller.text = local.descricaoCompleta;
    setState(() => _visivel = false);
    _foco.unfocus();
    widget.onSelecionado(local);
  }

  void _selecionarCampus(CampusDestino campus) {
    final local = campus.localizacao;
    if (local != null) return _selecionar(local);
    final termo =
        '${campus.sigla?.trim().isNotEmpty == true ? campus.sigla : campus.nome} '
        '${campus.campus} ${campus.cidade.cidade} ${campus.cidade.uf}';
    widget.controller.text = termo;
    widget.onChanged?.call(termo);
    setState(() {
      _confirmandoCampus = campus;
      _visivel = true;
    });
    _buscarEndereco(termo);
  }

  Future<void> _trocarCidade() async {
    var nome = _cidade?.cidade ?? '';
    final formulario = GlobalKey<FormState>();
    String? uf = _cidade?.uf;
    final cidade = await showDialog<CidadeCampus>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cidade das faculdades'),
        scrollable: true,
        content: Form(
          key: formulario,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: nome,
                onChanged: (valor) => nome = valor,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Cidade'),
                validator: (valor) =>
                    (valor?.trim().length ?? 0) < 2 ? 'Informe a cidade' : null,
              ),
              DropdownButtonFormField<String>(
                initialValue: uf,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Estado'),
                items: CidadeCampus.estados.entries
                    .map(
                      (estado) => DropdownMenuItem(
                        value: estado.key,
                        child: Text(
                          '${estado.key} · ${estado.value}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (valor) => uf = valor,
                validator: (valor) =>
                    valor == null ? 'Selecione o estado' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              if (formulario.currentState!.validate()) {
                Navigator.pop(context, CidadeCampus(nome.trim(), uf!));
              }
            },
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() => _visivel = true);
    if (cidade == null) return;
    _cidadeManual = true;
    await _carregarCampi(cidade);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_textoAlterado);
    _foco.removeListener(_focoAlterado);
    _foco.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final campi = _confirmandoCampus == null
        ? _campi.where((campus) => campus.corresponde(_filtro)).toList()
        : <CampusDestino>[];
    final locais = _locais
        .where((local) => !campi.any((campus) => campus.mesmoLocal(local)))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: _foco,
          onTap: () {
            setState(() => _visivel = true);
            if (!_iniciado) _iniciar();
          },
          onChanged: _aoDigitar,
          keyboardType: TextInputType.streetAddress,
          textInputAction: TextInputAction.search,
          style: const TextStyle(color: AppColors.text),
          onSubmitted: (texto) {
            _debounce?.cancel();
            _buscarEndereco(texto);
          },
          decoration: InputDecoration(
            labelText: 'Destino',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            prefixIcon: const Icon(
              Icons.location_on_outlined,
              color: AppColors.primary,
            ),
            suffixIcon: widget.controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Limpar destino',
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      widget.controller.clear();
                      widget.onChanged?.call('');
                      _foco.requestFocus();
                    },
                  ),
          ),
        ),
        if (_visivel) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  _cidade == null
                      ? 'Faculdades'
                      : 'Faculdades em ${_cidade!.cidade}/${_cidade!.uf}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: 'Alterar cidade',
                onPressed: _trocarCidade,
                icon: const Icon(Icons.location_city_outlined),
              ),
            ],
          ),
          if (_carregandoCampi) const LinearProgressIndicator(),
          if (!_carregandoCampi && _cidade == null)
            const Text('Localização indisponível. Selecione uma cidade.'),
          if (_erroCampi != null) ...[
            Text(_erroCampi!),
            TextButton.icon(
              onPressed: _carregandoCampi
                  ? null
                  : () => _carregarCampi(_cidade!),
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
          if (_confirmandoCampus != null)
            const Text('Confirme o endereço do campus nos resultados abaixo.'),
          if (!_carregandoCampi &&
              _erroCampi == null &&
              _cidade != null &&
              campi.isEmpty &&
              _confirmandoCampus == null)
            Text(
              _filtro.trim().isEmpty
                  ? 'Nenhuma faculdade cadastrada nesta cidade.'
                  : 'Nenhum campus corresponde à pesquisa.',
            ),
          if (campi.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.builder(
                primary: false,
                shrinkWrap: true,
                itemCount: campi.length,
                itemBuilder: (context, indice) {
                  final campus = campi[indice];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(campus.titulo),
                    subtitle: Text(
                      '${campus.cidade.cidade}/${campus.cidade.uf}',
                    ),
                    trailing: Icon(
                      campus.ponto == null ? Icons.search : Icons.chevron_right,
                    ),
                    onTap: () => _selecionarCampus(campus),
                  );
                },
              ),
            ),
          if (_buscandoEndereco) const LinearProgressIndicator(),
          if (locais.isNotEmpty) ...[
            const Divider(),
            const Text(
              'Endereços',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            for (final local in locais)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.place_outlined),
                title: Text(
                  local.nome?.isNotEmpty == true ? local.nome! : local.endereco,
                ),
                subtitle: local.nome?.isNotEmpty == true
                    ? Text(local.endereco)
                    : null,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _selecionar(local),
              ),
          ],
          if (_pesquisouEndereco &&
              !_buscandoEndereco &&
              locais.isEmpty &&
              campi.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Nenhum endereço encontrado. Tente rua, bairro e cidade.',
              ),
            ),
        ],
      ],
    );
  }
}
