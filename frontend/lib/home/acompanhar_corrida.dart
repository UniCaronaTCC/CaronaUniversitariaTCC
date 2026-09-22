import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../config/app_colors.dart';
import '../mapa/widgets/mapa_acompanhamento_passageiro.dart';
import '../models/posicao_atual_carona.dart';
import '../models/solicitacao_enviada.dart';
import '../services/carona_service.dart';
import '../widgets/componentes_padrao.dart';

class AcompanharCorridaTela extends StatefulWidget {
  final SolicitacaoEnviada solicitacao;

  const AcompanharCorridaTela({super.key, required this.solicitacao});

  @override
  State<AcompanharCorridaTela> createState() => _AcompanharCorridaTelaState();
}

class _AcompanharCorridaTelaState extends State<AcompanharCorridaTela> {
  static const _intervaloAtualizacao = Duration(seconds: 5);
  static const _limiteLocalizacaoAntiga = Duration(seconds: 20);

  Timer? _temporizador;
  PosicaoAtualCarona? _posicao;
  String? _erro;
  bool _consultando = false;
  bool _corridaEncerrada = false;

  @override
  void initState() {
    super.initState();
    _atualizarPosicao();
    _temporizador = Timer.periodic(
      _intervaloAtualizacao,
      (_) => _atualizarPosicao(),
    );
  }

  Future<void> _atualizarPosicao() async {
    if (_consultando || _corridaEncerrada) return;
    _consultando = true;
    try {
      final resultado = await CaronaService.buscarPosicaoAtual(
        widget.solicitacao.idCarona,
      );
      if (!mounted) return;

      if (resultado['sucesso'] == true) {
        setState(() {
          _posicao = resultado['dados'] as PosicaoAtualCarona?;
          _erro = null;
        });
        return;
      }

      final encerrada = resultado['corridaEncerrada'] == true;
      setState(() {
        _erro =
            resultado['mensagem']?.toString() ??
            'Não foi possível atualizar a localização do motorista';
        _corridaEncerrada = encerrada;
      });
      if (encerrada) {
        _temporizador?.cancel();
      }
    } finally {
      _consultando = false;
    }
  }

  bool get _localizacaoAntiga {
    final posicao = _posicao;
    if (posicao == null) return false;
    return DateTime.now().toUtc().difference(posicao.atualizadoEm.toUtc()) >
        _limiteLocalizacaoAntiga;
  }

  String get _textoStatus {
    if (_corridaEncerrada) return 'Esta corrida foi encerrada.';
    if (_posicao == null) {
      return 'Aguardando o motorista compartilhar a localização.';
    }
    if (_localizacaoAntiga) {
      return 'A última localização do motorista está antiga.';
    }
    return 'Localização do motorista atualizada.';
  }

  Color get _corStatus {
    if (_corridaEncerrada || _localizacaoAntiga) return Colors.orange.shade800;
    if (_posicao == null) return Colors.black54;
    return Colors.green.shade700;
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final posicao = _posicao;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const BarraSuperiorPadrao(titulo: 'Acompanhar motorista'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            children: [
              _CartaoStatus(
                motorista: widget.solicitacao.motorista,
                mensagem: _textoStatus,
                cor: _corStatus,
                atualizando: _consultando,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.15),
                    ),
                  ),
                  child: _corridaEncerrada
                      ? const _CorridaEncerrada()
                      : MapaAcompanhamentoPassageiro(
                          solicitacao: widget.solicitacao,
                          localizacaoMotorista: posicao == null
                              ? null
                              : LatLng(posicao.latitude, posicao.longitude),
                          direcaoMotorista: posicao?.direcao,
                        ),
                ),
              ),
              if (_erro != null && !_corridaEncerrada) ...[
                const SizedBox(height: 10),
                Text(
                  _erro!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CartaoStatus extends StatelessWidget {
  final String motorista;
  final String mensagem;
  final Color cor;
  final bool atualizando;

  const _CartaoStatus({
    required this.motorista,
    required this.mensagem,
    required this.cor,
    required this.atualizando,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.directions_car_filled_outlined, color: cor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  motorista,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(mensagem, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          if (atualizando)
            SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(color: cor, strokeWidth: 2),
            ),
        ],
      ),
    );
  }
}

class _CorridaEncerrada extends StatelessWidget {
  const _CorridaEncerrada();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flag_outlined, size: 42, color: Colors.black45),
            SizedBox(height: 12),
            Text('A corrida foi encerrada.', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
