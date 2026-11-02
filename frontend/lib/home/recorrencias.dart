import 'package:flutter/material.dart';
import '../models/recorrencia_carona.dart';
import '../services/recorrencia_service.dart';
import '../widgets/aviso_app.dart';
import '../widgets/componentes_padrao.dart';
import '../widgets/card_recorrencia.dart';
import '../widgets/visual_buscaeu.dart';
import 'ofertar_carona.dart';

class RecorrenciasTela extends StatefulWidget {
  final Future<List<RecorrenciaCarona>> Function()? carregar;
  final Future<void> Function(int, bool)? alterarEstado;
  const RecorrenciasTela({super.key, this.carregar, this.alterarEstado});
  @override
  State<RecorrenciasTela> createState() => _RecorrenciasTelaState();
}

class _RecorrenciasTelaState extends State<RecorrenciasTela> {
  List<RecorrenciaCarona> _modelos = [];
  bool _carregando = true;
  int? _alterando;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final modelos = await (widget.carregar ?? RecorrenciaService.listar)();
      if (mounted) setState(() => _modelos = modelos);
    } catch (_) {
      if (mounted) {
        setState(() => _erro = 'Não foi possível carregar suas recorrências.');
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _editar(RecorrenciaCarona modelo) async {
    final alterada = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => OfertarCaronaTela(
          caronaParaEditar: modelo.configuracao,
          idRecorrencia: modelo.id,
        ),
      ),
    );
    if (mounted && alterada == true) await _carregar();
  }

  Future<void> _alternar(RecorrenciaCarona modelo) async {
    setState(() => _alterando = modelo.id);
    try {
      await (widget.alterarEstado ?? RecorrenciaService.alterarEstado)(
        modelo.id,
        !modelo.ativa,
      );
      if (mounted) await _carregar();
    } catch (_) {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        AvisoApp.mostrar(
          context,
          'Não foi possível alterar a programação. Tente novamente.',
          tipo: TipoAviso.erro,
        );
      }
    } finally {
      if (mounted) setState(() => _alterando = null);
    }
  }

  @override
  Widget build(BuildContext context) => VisualBuscaEu(
    child: Scaffold(
      appBar: AppBar(title: const Text('Recorrências')),
      body: RefreshIndicator(
        onRefresh: _carregar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Suas programações publicam caronas para as próximas duas semanas. Cada dia tem seus próprios passageiros e pagamento.',
              style: VisualBuscaEu.descricao,
            ),
            const SizedBox(height: 12),
            const Text(
              'Editar vale para novas datas. Pausar interrompe novas publicações. As caronas já publicadas continuam disponíveis e podem ser editadas ou canceladas individualmente em Suas caronas.',
              style: VisualBuscaEu.descricao,
            ),
            const SizedBox(height: 20),
            if (_carregando)
              const Center(child: CircularProgressIndicator())
            else if (_erro != null)
              EstadoConteudoPadrao(
                icone: Icons.cloud_off_outlined,
                mensagem: _erro!,
                textoBotao: 'Tentar novamente',
                onPressed: _carregar,
              )
            else if (_modelos.isEmpty)
              const Text(
                'Nenhuma programação. Ao oferecer uma carona, ative a opção de recorrência.',
              )
            else
              ..._modelos.map(
                (modelo) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: CardRecorrencia(
                    recorrencia: modelo,
                    processando: _alterando == modelo.id,
                    bloqueada: _alterando != null,
                    onEditar: () => _editar(modelo),
                    onAlternar: () => _alternar(modelo),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
