import 'dart:async';

import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../mapa/models/localizacao_selecionada.dart';
import '../mapa/screens/mapa_screen.dart';
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
  final bool visualAtualizado;

  /// Controla a rolagem da tela; não deve ficar dentro de outra lista.
  final bool telaCompleta;

  const CampoDestinoCampus({
    super.key,
    required this.controller,
    required this.onSelecionado,
    this.onChanged,
    this.referenciaInicial,
    this.campusService = const CampusDestinoService(),
    this.enderecoService,
    this.mostrarAoAbrir = false,
    this.visualAtualizado = false,
    this.telaCompleta = false,
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
  String? _erroEndereco;
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
  bool _abrindoMapa = false;

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
      _erroEndereco = null;
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
      _erroEndereco = null;
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
    if (mounted &&
        consulta == _consultaCampi &&
        !_abrindoMapa &&
        _filtro.trim().length >= 3) {
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
    if (_buscandoEndereco) return;
    if (texto.trim().length < 3) return;
    final consulta = ++_consultaEndereco;
    setState(() {
      _buscandoEndereco = true;
      _pesquisouEndereco = false;
      _erroEndereco = null;
    });
    try {
      final usarReferencia =
          _cidade != null &&
          CidadeCampus.deLocalizacao(
                widget.referenciaInicial,
              )?.mesmaCidade(_cidade!) ==
              true;
      final pontoReferencia = usarReferencia
          ? widget.referenciaInicial?.ponto
          : _cidade?.pontoReferencia;
      final locais = await _enderecos.buscarLocalizacoesPorEndereco(
        texto,
        cidadeReferencia: _cidade?.cidade,
        estadoReferencia: CidadeCampus.estados[_cidade?.uf],
        latitudeReferencia: pontoReferencia?.latitude,
        longitudeReferencia: pontoReferencia?.longitude,
      );
      if (!mounted || consulta != _consultaEndereco) return;
      setState(() {
        _locais = locais.where((local) {
          final campus = _confirmandoCampus;
          if (campus == null) return true;
          return (local.pontoEspecifico ||
                  local.precisao == PrecisaoLocalizacao.rua) &&
              normalizarDestino(local.cidade ?? '') ==
                  normalizarDestino(campus.cidade.cidade) &&
              CidadeCampus.normalizarUf(local.estado) == campus.cidade.uf;
        }).toList();
      });
    } catch (erro) {
      if (!mounted || consulta != _consultaEndereco) return;
      setState(() => _erroEndereco = FalhaBuscaEndereco.mensagemPara(erro));
    } finally {
      if (mounted && consulta == _consultaEndereco) {
        setState(() {
          _buscandoEndereco = false;
          _pesquisouEndereco = true;
        });
      }
    }
  }

  Future<void> _selecionar(LocalizacaoSelecionada local) async {
    if (_abrindoMapa) return;
    _debounce?.cancel();
    final consulta = ++_consultaEndereco;
    final texto = widget.controller.text;
    if (local.exigeAjusteNoMapa) {
      _abrindoMapa = true;
      setState(() {
        _buscandoEndereco = false;
        _erroEndereco = null;
      });
      try {
        final confirmado = await Navigator.of(context)
            .push<LocalizacaoSelecionada>(
              MaterialPageRoute(
                builder: (_) => TesteMapa(
                  titulo: 'Confirmar destino',
                  ajusteOpcional: true,
                  textoBotao: 'CONFIRMAR DESTINO',
                  localizacaoInicial: local,
                  enderecoService: _enderecos,
                ),
              ),
            );
        if (!mounted ||
            consulta != _consultaEndereco ||
            widget.controller.text != texto ||
            confirmado == null ||
            !confirmado.localConfirmavel) {
          return;
        }
        local = confirmado;
      } finally {
        _abrindoMapa = false;
      }
    }
    if (!mounted) return;
    widget.controller.text = local.descricaoCompleta;
    setState(() => _visivel = false);
    _foco.unfocus();
    widget.onSelecionado(local);
  }

  void _selecionarCampus(CampusDestino campus) {
    final local = campus.localizacao;
    if (local != null) {
      _selecionar(local);
      return;
    }
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
    final visualCampoAtualizado =
        widget.telaCompleta || widget.visualAtualizado;
    final campi = _confirmandoCampus == null
        ? _campi.where((campus) => campus.corresponde(_filtro)).toList()
        : <CampusDestino>[];
    final locais = _locais
        .where((local) => !campi.any((campus) => campus.mesmoLocal(local)))
        .toList();
    final cabecalho = <Widget>[
      if (widget.telaCompleta) ...[
        const Text(
          'Para onde você vai?',
          style: TextStyle(
            color: Color(0xFF151824),
            fontSize: 26,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 24),
      ],
      if (visualCampoAtualizado) ...[
        const Text(
          'Destino',
          style: TextStyle(
            color: Color(0xFF151824),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
      ],
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
          labelText: visualCampoAtualizado ? null : 'Destino',
          hintText: visualCampoAtualizado ? 'Faculdade ou endereço' : null,
          hintStyle: const TextStyle(color: Color(0xFF646B7B)),
          filled: true,
          fillColor: visualCampoAtualizado
              ? const Color(0xFFF6F6F9)
              : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(visualCampoAtualizado ? 8 : 16),
            borderSide: visualCampoAtualizado
                ? const BorderSide(color: Color(0xFFDADCE5))
                : BorderSide.none,
          ),
          enabledBorder: visualCampoAtualizado
              ? OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFDADCE5)),
                )
              : null,
          focusedBorder: visualCampoAtualizado
              ? OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                )
              : null,
          prefixIcon: Icon(
            visualCampoAtualizado ? Icons.search : Icons.location_on_outlined,
            color: visualCampoAtualizado
                ? const Color(0xFF646B7B)
                : AppColors.primary,
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
        if (widget.telaCompleta)
          _cidadeTelaCompleta()
        else
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
        if (widget.telaCompleta) ...[
          const SizedBox(height: 20),
          const Text(
            'Faculdades',
            style: TextStyle(
              color: Color(0xFF151824),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (_carregandoCampi) const LinearProgressIndicator(),
        if (!_carregandoCampi && _cidade == null)
          const Text('Localização indisponível. Selecione uma cidade.'),
        if (_erroCampi != null) ...[
          Text(_erroCampi!),
          TextButton.icon(
            onPressed: _carregandoCampi ? null : () => _carregarCampi(_cidade!),
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
      ],
    ];
    final avisosEndereco = <Widget>[
      if (_visivel) ...[
        if (_buscandoEndereco) const LinearProgressIndicator(),
        if (_erroEndereco != null) ...[
          Text(_erroEndereco!),
          TextButton.icon(
            onPressed: _buscandoEndereco
                ? null
                : () => _buscarEndereco(widget.controller.text),
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente'),
          ),
        ],
        if (locais.isNotEmpty) ...[
          const Divider(),
          const Text(
            'Endereços',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ],
    ];
    final rodape = <Widget>[
      if (_visivel &&
          _pesquisouEndereco &&
          _erroEndereco == null &&
          !_buscandoEndereco &&
          locais.isEmpty &&
          campi.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Nenhum endereço encontrado. Tente rua, bairro e cidade.',
          ),
        ),
    ];
    if (widget.telaCompleta) {
      // Uma rolagem, com resultados criados sob demanda, mesmo em cidades grandes.
      return CustomScrollView(
        key: const ValueKey('rolagem-escolher-destino'),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            sliver: SliverList.list(children: cabecalho),
          ),
          if (_visivel) ...[
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverList.builder(
                itemCount: campi.length,
                itemBuilder: (context, indice) => _itemCampus(campi[indice]),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverList.list(children: avisosEndereco),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverList.builder(
                itemCount: locais.length,
                itemBuilder: (context, indice) => _itemEndereco(locais[indice]),
              ),
            ),
          ],
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            sliver: SliverList.list(children: rodape),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...cabecalho,
        if (_visivel) ...[
          if (campi.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.builder(
                primary: false,
                shrinkWrap: true,
                itemCount: campi.length,
                itemBuilder: (context, indice) {
                  return _itemCampus(campi[indice]);
                },
              ),
            ),
          ...avisosEndereco,
          for (final local in locais) _itemEndereco(local),
        ],
        ...rodape,
      ],
    );
  }

  Widget _cidadeTelaCompleta() {
    return Row(
      children: [
        const Icon(
          Icons.location_on_outlined,
          color: AppColors.primary,
          size: 22,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _cidade == null
                ? 'Selecionar cidade'
                : '${_cidade!.cidade}, ${_cidade!.uf}',
            style: const TextStyle(color: Color(0xFF646B7B), fontSize: 14),
          ),
        ),
        Tooltip(
          message: 'Alterar cidade',
          child: TextButton.icon(
            onPressed: _trocarCidade,
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            icon: const Icon(Icons.keyboard_arrow_down, size: 20),
            iconAlignment: IconAlignment.end,
            label: const Text('Alterar'),
          ),
        ),
      ],
    );
  }

  Widget _itemCampus(CampusDestino campus) {
    final tituloEstilo = widget.telaCompleta
        ? Theme.of(context).textTheme.titleMedium?.copyWith(
            color: const Color(0xFF151824),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          )
        : null;
    final subtituloEstilo = widget.telaCompleta
        ? Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF646B7B),
            fontSize: 14,
          )
        : null;
    final indicador = Icon(
      campus.ponto == null ? Icons.search : Icons.chevron_right,
      color: widget.telaCompleta ? const Color(0xFF646B7B) : null,
    );
    if (widget.telaCompleta &&
        MediaQuery.textScalerOf(context).scale(16) > 24) {
      return InkWell(
        key: ValueKey('campus-destino-${campus.idCampus}'),
        onTap: () => _selecionarCampus(campus),
        child: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _iconeResultado(Icons.school_outlined),
                  const Spacer(),
                  indicador,
                ],
              ),
              const SizedBox(height: 12),
              Text(campus.titulo, style: tituloEstilo),
              const SizedBox(height: 4),
              Text(
                '${campus.cidade.cidade}, ${campus.cidade.uf}',
                style: subtituloEstilo,
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFE9E9EF)),
            ],
          ),
        ),
      );
    }
    final item = ListTile(
      key: ValueKey('campus-destino-${campus.idCampus}'),
      contentPadding: widget.telaCompleta
          ? const EdgeInsets.symmetric(vertical: 8)
          : EdgeInsets.zero,
      leading: widget.telaCompleta
          ? _iconeResultado(Icons.school_outlined)
          : null,
      horizontalTitleGap: widget.telaCompleta ? 12 : null,
      title: Text(campus.titulo),
      titleTextStyle: tituloEstilo,
      subtitle: Text(
        widget.telaCompleta
            ? '${campus.cidade.cidade}, ${campus.cidade.uf}'
            : '${campus.cidade.cidade}/${campus.cidade.uf}',
      ),
      subtitleTextStyle: subtituloEstilo,
      trailing: indicador,
      onTap: () => _selecionarCampus(campus),
    );
    if (!widget.telaCompleta) return item;
    return Column(
      children: [
        item,
        const Divider(height: 1, color: Color(0xFFE9E9EF)),
      ],
    );
  }

  Widget _iconeResultado(IconData icone) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFF3E8FC),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icone, color: AppColors.primary, size: 22),
    );
  }

  Widget _itemEndereco(LocalizacaoSelecionada local) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: widget.telaCompleta
          ? _iconeResultado(Icons.place_outlined)
          : const Icon(Icons.place_outlined),
      title: Text(
        local.nome?.isNotEmpty == true ? local.nome! : local.endereco,
      ),
      subtitle:
          local.nome?.isNotEmpty == true ||
              local.avisoPrecisaoPara(ajusteOpcional: true) != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (local.nome?.isNotEmpty == true) Text(local.endereco),
                if (local.avisoPrecisaoPara(ajusteOpcional: true) != null)
                  Text(local.avisoPrecisaoPara(ajusteOpcional: true)!),
              ],
            )
          : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _selecionar(local),
    );
  }
}
