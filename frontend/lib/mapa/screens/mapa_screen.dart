import 'package:flutter/material.dart'; // Importa os componentes visuais do Flutter
import 'package:flutter_map/flutter_map.dart'; // Importa o mapa OpenStreetMap
import 'package:latlong2/latlong.dart'; // Importa o tipo LatLng para latitude e longitude

import '../services/endereco_service.dart'; // Service que converte coordenadas em endereco
import '../services/localizacao_service.dart'; // Service que pega a localizacao atual
import '../models/localizacao_selecionada.dart'; // Model com ponto e endereco escolhido
import '../widgets/barra_pesquisa_endereco.dart'; // barra de pesquisa
import '../../navigation/navegacao_principal.dart';
import '../../widgets/barra_navegacao_home.dart';
import '../../widgets/componentes_padrao.dart';

class TesteMapa extends StatefulWidget {
  final String titulo;
  final String instrucao;
  final String textoBotao;
  final int indiceNavegacao;

  const TesteMapa({
    super.key,
    this.titulo = 'Confirmar origem',
    this.instrucao = 'Confira sua origem',
    this.textoBotao = 'CONFIRMAR ORIGEM',
    this.indiceNavegacao = 0,
  });

  @override
  State<TesteMapa> createState() => _TesteMapaState();
}

class _TesteMapaState extends State<TesteMapa> {
  final LocalizacaoService _localizacaoService = LocalizacaoService();
  final EnderecoService _enderecoService = EnderecoService();
  final MapController _mapController = MapController();

  LatLng? _localizacaoAtual;
  LatLng? _pontoEncontro;

  String? _enderecoPontoEncontro;
  String? _cidadePontoEncontro;

  bool _buscandoLocalizacao = true;
  bool _buscandoEndereco = false;

  @override
  void initState() {
    super.initState();
    _obterLocalizacao();
  }

  // Obtem a localizacao atual, centraliza o mapa e busca o endereco estimado
  Future<void> _obterLocalizacao() async {
    try {
      final posicao = await _localizacaoService.obterLocalizacaoAtual();

      if (!mounted) {
        return;
      }

      final pontoAtual = LatLng(posicao.latitude, posicao.longitude);

      setState(() {
        _localizacaoAtual = pontoAtual;
        _pontoEncontro = pontoAtual;
        _buscandoLocalizacao = false;
      });

      // Abre o mapa na localizacao atual do usuario
      _mapController.move(pontoAtual, 16);

// Busca o endereco aproximado da localizacao atual
      await _buscarEnderecoDoPonto(pontoAtual);
    } catch (erro) {
      debugPrint('Erro ao obter localizacao: $erro');

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

  // Busca o endereco a partir de um ponto do mapa
  Future<void> _buscarEnderecoDoPonto(LatLng ponto) async {
    setState(() {
      _buscandoEndereco = true;
      _enderecoPontoEncontro = null;
      _cidadePontoEncontro = null;
    });

    final localizacao = await _enderecoService.buscarLocalizacaoPorCoordenadas(
      ponto.latitude,
      ponto.longitude,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _enderecoPontoEncontro =
          localizacao?.endereco ?? 'Endereço não encontrado';
      _cidadePontoEncontro = localizacao?.cidade;
      _buscandoEndereco = false;
    });
  }

  // Permite ajustar manualmente o ponto tocando no mapa
  Future<void> _selecionarPonto(LatLng ponto) async {
    setState(() {
      _pontoEncontro = ponto;
    });

    await _buscarEnderecoDoPonto(ponto);
  }

  // Move o mapa para uma das opções encontradas pela pesquisa.
  void _selecionarEnderecoPesquisado(LocalizacaoSelecionada local) {
    setState(() {
      _pontoEncontro = local.ponto;
      _enderecoPontoEncontro = local.endereco;
      _cidadePontoEncontro = local.cidade;
      _buscandoEndereco = false;
    });

    _mapController.move(local.ponto, 16);
  }

  void _confirmarPontoEncontro() {
    if (_pontoEncontro == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aguarde a localização ou toque no mapa')),
      );

      return;
    }

    if (Navigator.canPop(context)) {
      Navigator.pop(
        context,
        LocalizacaoSelecionada(
          ponto: _pontoEncontro!,
          endereco: _enderecoPontoEncontro ?? 'Endereço não encontrado',
          cidade: _cidadePontoEncontro,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Ponto confirmado')));
  }

  @override
  Widget build(BuildContext context) {
    final bool mesmoPonto =
        _localizacaoAtual != null &&
            _pontoEncontro != null &&
            _localizacaoAtual == _pontoEncontro;

    return Scaffold(
      appBar: BarraSuperiorPadrao(titulo: widget.titulo),

      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,

            options: MapOptions(
              // Ponto inicial temporario enquanto o GPS carrega
              initialCenter: const LatLng(-21.2080, -50.4320),
              initialZoom: 14,

              // Se o endereco estimado estiver errado, o usuario pode ajustar no mapa
              onTap: (tapPosition, point) {
                _selecionarPonto(point);
              },
            ),

            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.unicarona.app',
              ),

              // if (_localizacaoAtual != null)
              //   MarkerLayer(
              //     markers: [
              //       Marker(
              //         point: _localizacaoAtual!,
              //         width: 50,
              //         height: 50,
              //         child: const Icon(
              //           Icons.my_location,
              //           color: Colors.red,
              //           size: 38,
              //         ),
              //       ),
              //     ],
              //   ),

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

          // Barra de pesquisa sobre o mapa
          SafeArea(
            child: BarraPesquisaEndereco(
              onSelecionado: _selecionarEnderecoPesquisado,
            ),
          ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: SafeArea(
              top: false,
              bottom: false,
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
                      _enderecoPontoEncontro ??
                          'Toque no mapa para ajustar a origem',
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _pontoEncontro == null
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