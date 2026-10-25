import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/dados_veiculo.dart';

class DialogoVeiculo extends StatefulWidget {
  final Map<String, dynamic> veiculo;
  final Future<Map<String, dynamic>> Function(String, String, String) salvar;

  const DialogoVeiculo({
    super.key,
    required this.veiculo,
    required this.salvar,
  });

  @override
  State<DialogoVeiculo> createState() => _DialogoVeiculoState();
}

class _DialogoVeiculoState extends State<DialogoVeiculo> {
  static const _outraCor = 'outra-cor';
  static const _amostras = [
    Color(0xFFF2CB32),
    Color(0xFF3069B2),
    Color(0xFFD0BC99),
    Colors.white,
    Color(0xFF777777),
    Color(0xFFB79A45),
    null,
    Color(0xFF7A2940),
    Color(0xFFE78330),
    Color(0xFF805A3B),
    Color(0xFFC4C7CB),
    Colors.black,
    Color(0xFFE39AAE),
    Color(0xFF8758A6),
    Color(0xFF387B50),
    Color(0xFFC84040),
  ];
  final _form = GlobalKey<FormState>();
  late final TextEditingController _modelo;
  late final TextEditingController _placa;
  late final TextEditingController _corPersonalizada;
  String? _cor;
  String? _erro;
  Map<String, String> _errosCampos = {};
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _modelo = TextEditingController(
      text: widget.veiculo['modelo']?.toString() ?? '',
    );
    _placa = TextEditingController(
      text: widget.veiculo['placa']?.toString() ?? '',
    );
    final cor = widget.veiculo['cor']?.toString() ?? '';
    _cor = cor.isEmpty ? null : DadosVeiculo.corPadrao(cor) ?? _outraCor;
    _corPersonalizada = TextEditingController(text: cor);
  }

  @override
  void dispose() {
    _modelo.dispose();
    _placa.dispose();
    _corPersonalizada.dispose();
    super.dispose();
  }

  void _limparErro(String campo) {
    if (_errosCampos.containsKey(campo)) {
      setState(() => _errosCampos.remove(campo));
    }
  }

  Future<void> _salvar() async {
    if (_enviando || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _enviando = true;
      _erro = null;
    });
    Map<String, dynamic> resultado;
    try {
      resultado = await widget.salvar(
        DadosVeiculo.normalizarTexto(_modelo.text),
        _cor == _outraCor
            ? DadosVeiculo.normalizarTexto(_corPersonalizada.text)
            : _cor!,
        DadosVeiculo.normalizarPlaca(_placa.text),
      );
    } catch (_) {
      resultado = {
        'sucesso': false,
        'mensagem':
            'N\u00e3o foi poss\u00edvel confirmar a altera\u00e7\u00e3o. Confira a conex\u00e3o e atualize o perfil antes de tentar novamente',
      };
    }
    if (!mounted) return;
    if (resultado['sucesso'] == true && resultado['dados'] is Map) {
      Navigator.pop(context, resultado);
      return;
    }
    final campos = resultado['campos'];
    final erros = <String, String>{};
    if (campos is Map) {
      for (final campo in ['modelo', 'cor', 'placa']) {
        final mensagem = campos[campo];
        if (mensagem is String && mensagem.trim().isNotEmpty) {
          erros[campo] = mensagem;
        }
      }
    }
    setState(() {
      _enviando = false;
      _errosCampos = erros;
      _erro = erros.isEmpty
          ? resultado['mensagem']?.toString() ??
                'N\u00e3o foi poss\u00edvel salvar o ve\u00edculo. Tente novamente'
          : null;
    });
    _form.currentState!.validate();
  }

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_enviando,
      child: AlertDialog(
        title: Text(
          widget.veiculo.isEmpty
              ? 'Cadastrar ve\u00edculo'
              : 'Editar ve\u00edculo',
        ),
        scrollable: true,
        content: SizedBox(
          width: 400,
          child: Form(
            key: _form,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.veiculo.isNotEmpty) ...[
                  const Text(
                    'As caronas j\u00e1 publicadas mant\u00eam o ve\u00edculo informado.',
                  ),
                  const SizedBox(height: 20),
                ],
                TextFormField(
                  key: const Key('veiculo-modelo'),
                  controller: _modelo,
                  enabled: !_enviando,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    labelText: 'Marca e modelo',
                    hintText: 'Honda Civic',
                    errorMaxLines: 3,
                    border: OutlineInputBorder(),
                  ),
                  validator: (valor) =>
                      _errosCampos['modelo'] ??
                      DadosVeiculo.validarModelo(valor),
                  onChanged: (_) => _limparErro('modelo'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const Key('veiculo-cor'),
                  initialValue: _cor,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Cor',
                    errorMaxLines: 3,
                    prefixIcon: Icon(Icons.palette_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (var i = 0; i < DadosVeiculo.cores.length; i++)
                      DropdownMenuItem(
                        value: DadosVeiculo.cores[i],
                        child: Row(
                          children: [
                            if (_amostras[i] != null)
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: _amostras[i],
                                  shape: BoxShape.circle,
                                  border: Border.all(color: cores.outline),
                                ),
                              )
                            else
                              const Icon(Icons.palette_outlined, size: 16),
                            const SizedBox(width: 10),
                            Expanded(child: Text(DadosVeiculo.cores[i])),
                          ],
                        ),
                      ),
                    const DropdownMenuItem(
                      value: _outraCor,
                      child: Text('Outra cor'),
                    ),
                  ],
                  onChanged: _enviando
                      ? null
                      : (valor) => setState(() {
                          _cor = valor;
                          _errosCampos.remove('cor');
                        }),
                  validator: (valor) => valor == null
                      ? 'Selecione a cor do ve\u00edculo'
                      : valor == _outraCor
                      ? null
                      : _errosCampos['cor'],
                ),
                if (_cor == _outraCor) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('veiculo-outra-cor'),
                    controller: _corPersonalizada,
                    enabled: !_enviando,
                    maxLength: 50,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Outra cor',
                      hintText: 'Azul escuro',
                      errorMaxLines: 3,
                      border: OutlineInputBorder(),
                    ),
                    validator: (valor) =>
                        _errosCampos['cor'] ?? DadosVeiculo.validarCor(valor),
                    onChanged: (_) => _limparErro('cor'),
                  ),
                ],
                const SizedBox(height: 20),
                TextFormField(
                  key: const Key('veiculo-placa'),
                  controller: _placa,
                  enabled: !_enviando,
                  maxLength: 9,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    TextInputFormatter.withFunction(
                      (antigo, novo) =>
                          novo.copyWith(text: novo.text.toUpperCase()),
                    ),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Placa',
                    hintText: 'ABC1D23 ou ABC-1234',
                    errorMaxLines: 3,
                    counterText: '',
                    prefixIcon: Icon(Icons.pin_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (valor) =>
                      _errosCampos['placa'] ?? DadosVeiculo.validarPlaca(valor),
                  onChanged: (_) => _limparErro('placa'),
                  onFieldSubmitted: (_) => _salvar(),
                ),
                if (_erro != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(_erro!, style: TextStyle(color: cores.error)),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _enviando ? null : () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            key: const Key('veiculo-salvar'),
            onPressed: _enviando ? null : _salvar,
            icon: _enviando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_enviando ? 'Salvando...' : 'Salvar'),
          ),
        ],
      ),
    );
  }
}
