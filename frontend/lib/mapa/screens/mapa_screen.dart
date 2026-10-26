import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../navigation/navegacao_principal.dart';
import '../../widgets/barra_navegacao_home.dart';
import '../../widgets/componentes_padrao.dart';
import '../models/localizacao_selecionada.dart';
import '../services/endereco_service.dart';
import '../services/localizacao_service.dart';
import '../widgets/barra_pesquisa_endereco.dart';

class TesteMapa extends StatefulWidget {
  final String titulo;
  final String instrucao;
  final String textoBotao;
  final int indiceNavegacao;
  final EnderecoService? enderecoService;
  final LocalizacaoSelecionada? localizacaoInicial;

  const TesteMapa({
    super.key,
    this.titulo = 'Confirmar local',
    this.instrucao = 'Confira o local selecionado',
    this.textoBotao = 'CONFIRMAR LOCAL',
    this.indiceNavegacao = 0,
    this.enderecoService,
    this.localizacaoInicial,
  });

  @override
  State<TesteMapa> createState() => _TesteMapaState();
}

class _TesteMapaState extends State<TesteMapa> {
  final LocalizacaoService _localizacaoService = LocalizacaoService();
  late final EnderecoService _enderecoService =
      widget.enderecoService ?? EnderecoService();
  final MapController _mapController = MapController();

  LatLng? _localizacaoAtual;
  LatLng? _pontoEncontro;

  String? _enderecoPontoEncontro;
  String? _nomePontoEncontro;
  String? _cidadePontoEncontro;
  String? _estadoPontoEncontro;
  String? _rua;
  String? _numero;
  String? _avisoPrecisao;
  bool _exigeAjuste = false;

  bool _buscandoLocalizacao = true;
  bool _buscandoEndereco = false;
  bool _pontoEspecifico = true;
  int _consultaEndereco = 0;

  @override
  void initState() {
    super.initState();
    final inicial = widget.localizacaoInicial;
    if (inicial != null && inicial.coordenadasValidas) {
      _pontoEncontro = inicial.ponto;
      _nomePontoEncontro = inicial.nome;
      _enderecoPontoEncontro = inicial.endereco;
      _cidadePontoEncontro = inicial.cidade;
      _estadoPontoEncontro = inicial.estado;
      _rua = inicial.rua;
      _numero = inicial.numero;
      _pontoEspecifico = inicial.pontoEspecifico;
      _exigeAjuste = inicial.exigeAjusteNoMapa;
      _avisoPrecisao = inicial.avisoPrecisao;
      _buscandoLocalizacao = false;
    } else {
      _obterLocalizacao();
    }
  }

  // Obtém a localização atual e centraliza o mapa.
  Future<void> _obterLocalizacao() async {
    try {
      final posicao = await _localizacaoService.obterLocalizacaoAtual().timeout(
        const Duration(seconds: 8),
      );

      if (!mounted) {
        return;
      }

      final pontoAtual = LatLng(posicao.latitude, posicao.longitude);

      setState(() {
        _localizacaoAtual = pontoAtual;
        _pontoEncontro = pontoAtual;
        _buscandoLocalizacao = false;
        _pontoEspecifico = true;
      });

      await _buscarEnderecoDoPonto(pontoAtual);
    } catch (erro) {
      debugPrint('Erro ao obter localização: $erro');

      if (!mounted) {
        return;
      }

      setState(() {
        _buscandoLocalizacao = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível obter sua localização')),
      );
    }
  }

  // Busca o endereço correspondente ao ponto escolhido.
  Future<void> _buscarEnderecoDoPonto(LatLng ponto) async {
    final consulta = ++_consultaEndereco;
    setState(() {
      _buscandoEndereco = true;
      _enderecoPontoEncontro = null;
      _nomePontoEncontro = null;
      _cidadePontoEncontro = null;
      _estadoPontoEncontro = null;
      _rua = null;
      _numero = null;
    });

    LocalizacaoSelecionada? localizacao;
    try {
      localizacao = await _enderecoService.buscarLocalizacaoPorCoordenadas(
        ponto.latitude,
        ponto.longitude,
      );
    } catch (_) {
      localizacao = null;
    }

    if (!mounted || consulta != _consultaEndereco) {
      return;
    }

    setState(() {
      _enderecoPontoEncontro =
          localizacao?.endereco ?? 'Endereço não encontrado';

      _nomePontoEncontro = localizacao?.nome;
      _cidadePontoEncontro = localizacao?.cidade;
      _estadoPontoEncontro = localizacao?.estado;
      _rua = localizacao?.rua;
      _numero = localizacao?.numero;

      _buscandoEndereco = false;
    });
  }

  // Permite ajustar o ponto tocando no mapa.
  Future<void> _selecionarPonto(LatLng ponto) async {
    setState(() {
      _pontoEncontro = ponto;
      _pontoEspecifico = true;
      _exigeAjuste = false;
      _avisoPrecisao = null;
    });

    await _buscarEnderecoDoPonto(ponto);
  }

  // Move o mapa para o resultado selecionado na pesquisa.
  void _selecionarEnderecoPesquisado(LocalizacaoSelecionada local) {
    _consultaEndereco++;
    setState(() {
      _pontoEncontro = local.ponto;

      _nomePontoEncontro = local.nome;
      _enderecoPontoEncontro = local.endereco;
      _cidadePontoEncontro = local.cidade;
      _estadoPontoEncontro = local.estado;
      _pontoEspecifico = local.pontoEspecifico;
      _exigeAjuste = local.exigeAjusteNoMapa;
      _avisoPrecisao = local.avisoPrecisao;
      _rua = local.rua;
      _numero = local.numero;

      _buscandoEndereco = false;
    });

    _mapController.move(local.ponto, 16);
  }

  Future<void> _usarLocalizacaoAtual() async {
    final ponto = _localizacaoAtual;
    if (ponto == null) return;
    _mapController.move(ponto, 16);
    await _selecionarPonto(ponto);
  }

  void _confirmarPontoEncontro() {
    if (_pontoEncontro == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aguarde a localização ou toque no mapa')),
      );

      return;
    }

    final localSelecionado = LocalizacaoSelecionada(
      ponto: _pontoEncontro!,
      endereco: _enderecoPontoEncontro ?? 'Endereço não encontrado',
      cidade: _cidadePontoEncontro,
      estado: _estadoPontoEncontro,
      nome: _nomePontoEncontro,
      pontoEspecifico: _pontoEspecifico,
      rua: _rua,
      numero: _numero,
      precisao: PrecisaoLocalizacao.ponto,
    );

    if (!localSelecionado.coordenadasValidas) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('O ponto escolhido possui coordenadas inválidas'),
        ),
      );
      return;
    }

    if (!_pontoEspecifico || _exigeAjuste) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Toque no mapa para confirmar o ponto exato'),
        ),
      );
      return;
    }

    if (Navigator.canPop(context)) {
      Navigator.pop(context, localSelecionado);

      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Ponto confirmado')));
  }

  @override
  Widget build(BuildContext context) {
    final mesmoPonto =
        _localizacaoAtual != null &&
        _pontoEncontro != null &&
        _localizacaoAtual == _pontoEncontro;

    final pontoReferencia = _pontoEncontro ?? _localizacaoAtual;

    return Scaffold(
      appBar: BarraSuperiorPadrao(titulo: widget.titulo),
      body: Stack(
        children: [
          if (_buscandoLocalizacao)
            const ColoredBox(
              color: Color(0xFFF7F4F8),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Obtendo sua localização...'),
                  ],
                ),
              ),
            )
          else ...[
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter:
                    _pontoEncontro ??
                    _localizacaoAtual ??
                    const LatLng(-14.235, -51.9253),
                initialZoom: _pontoEncontro == null
                    ? 4
                    : widget.localizacaoInicial?.precisao ==
                          PrecisaoLocalizacao.regiao
                    ? 11
                    : 16,
                onTap: (tapPosition, point) {
                  _selecionarPonto(point);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.unicarona.app',
                ),
                if (_localizacaoAtual != null && !mesmoPonto)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _localizacaoAtual!,
                        width: 50,
                        height: 50,
                        child: const Icon(
                          Icons.my_location,
                          color: Colors.red,
                          size: 38,
                        ),
                      ),
                    ],
                  ),
                if (_pontoEncontro != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _pontoEncontro!,
                        width: 50,
                        height: 50,
                        child: const Icon(
                          Icons.place,
                          color: Colors.blue,
                          size: 42,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            SafeArea(
              child: SingleChildScrollView(
                child: BarraPesquisaEndereco(
                  onSelecionado: _selecionarEnderecoPesquisado,
                  latitudeReferencia: pontoReferencia?.latitude,
                  longitudeReferencia: pontoReferencia?.longitude,
                  cidadeReferencia: _cidadePontoEncontro,
                  estadoReferencia: _estadoPontoEncontro,
                ),
              ),
            ),
            if (_localizacaoAtual != null)
              Positioned(
                right: 12,
                bottom: 12,
                child: FloatingActionButton.small(
                  heroTag: null,
                  tooltip: 'Usar minha localização',
                  onPressed: _usarLocalizacaoAtual,
                  child: const Icon(Icons.my_location),
                ),
              ),
          ],
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            constraints: BoxConstraints(
              maxHeight:
                  (MediaQuery.sizeOf(context).height -
                      MediaQuery.viewInsetsOf(context).bottom) *
                  0.45,
            ),
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: SafeArea(
              top: false,
              bottom: false,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _buscandoLocalizacao
                          ? 'Obtendo sua localização...'
                          : widget.instrucao,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),

                    const SizedBox(height: 8),

                    if (_buscandoEndereco)
                      const Text('Buscando endereço...')
                    else
                      Text(
                        _nomePontoEncontro != null &&
                                _nomePontoEncontro!.trim().isNotEmpty
                            ? '$_nomePontoEncontro - '
                                  '${_enderecoPontoEncontro ?? ''}'
                            : _enderecoPontoEncontro ??
                                  'Toque no mapa para escolher o ponto',
                      ),

                    const SizedBox(height: 12),

                    if (_avisoPrecisao != null) ...[
                      Text(_avisoPrecisao!),
                      const SizedBox(height: 8),
                    ],

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _pontoEncontro == null || _buscandoEndereco
                            ? null
                            : _confirmarPontoEncontro,
                        icon: const Icon(Icons.check),
                        label: Text(widget.textoBotao),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          BarraNavegacaoHome(
            currentIndex: widget.indiceNavegacao,
            onTap: (indice) => NavegacaoPrincipal.selecionar(
              context,
              indice,
              indiceAtual: widget.indiceNavegacao,
            ),
          ),
        ],
      ),
    );
  }
}
