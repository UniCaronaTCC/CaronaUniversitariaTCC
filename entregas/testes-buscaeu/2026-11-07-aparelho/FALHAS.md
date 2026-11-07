# Apontamentos dos testes no aparelho

## Conversas historico avaliacoes e recorrencias visual chat: chat com teclado

Fonte: `frontend/test/proximas_telas_visual_test.dart`. Estado da evidencia: `FALHOU`. Runner: `FALHOU`.



```text
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: null
  Actual: FlutterError:<A RenderFlex overflowed by 66 pixels on the bottom.>
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞══════════════════════
The following assertion was thrown during layout:
A RenderFlex overflowed by 66 pixels on the bottom.

The relevant error-causing widget was:
  Column
  Column:file:///[copia QA]/lib/widgets/componentes_padrao.dart:38:16

The overflowing RenderFlex has an orientation of Axis.vertical.
The edge of the RenderFlex that is overflowing has been marked in
the rendering with a yellow and black striped pattern. This is
usually caused by the contents being too big for the RenderFlex.
Consider applying a flex factor (e.g. using an Expanded widget)
to force the children of the RenderFlex to fit within the
available space instead of being sized to their natural size.
This is considered an error condition because it indicates that
there is content that cannot be seen. If the content is
legitimately bigger than the available space, consider clipping
it with a ClipRect widget before putting it in the flex, or using
a scrollable container rather than a Flex, like a ListView.
The specific RenderFlex in question is: RenderFlex#0401f relayoutBoundary=up5 OVERFLOWING:
  parentData: offset=Offset(0.0, 28.0) (can use size)
  constraints: BoxConstraints(0.0<=w<=320.0, 0.0<=h<=84.0)
  size: Size(320.0, 84.0)
  direction: vertical
  mainAxisAlignment: start
  mainAxisSize: min
  crossAxisAlignment: center
  verticalDirection: down
  spacing: 0.0
◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤
═════════════════════════════════════════════════════════════════

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///[copia QA]/test/proximas_telas_visual_test.dart:269:9)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1059:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///[copia QA]/test/proximas_telas_visual_test.dart line 269
The test description was:
  chat: chat com teclado
Test failed. See exception logs above.
The test description was: chat: chat com teclado
```

## Conversas historico avaliacoes e recorrencias visual chat: chat encerrado

Fonte: `frontend/test/proximas_telas_visual_test.dart`. Estado da evidencia: `FALHOU`. Runner: `FALHOU`.



```text
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: null
  Actual: FlutterError:<A RenderFlex overflowed by 77 pixels on the bottom.>
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞══════════════════════
The following assertion was thrown during layout:
A RenderFlex overflowed by 77 pixels on the bottom.

The relevant error-causing widget was:
  Column
  Column:file:///[copia QA]/lib/widgets/componentes_padrao.dart:38:16

The overflowing RenderFlex has an orientation of Axis.vertical.
The edge of the RenderFlex that is overflowing has been marked in
the rendering with a yellow and black striped pattern. This is
usually caused by the contents being too big for the RenderFlex.
Consider applying a flex factor (e.g. using an Expanded widget)
to force the children of the RenderFlex to fit within the
available space instead of being sized to their natural size.
This is considered an error condition because it indicates that
there is content that cannot be seen. If the content is
legitimately bigger than the available space, consider clipping
it with a ClipRect widget before putting it in the flex, or using
a scrollable container rather than a Flex, like a ListView.
The specific RenderFlex in question is: RenderFlex#1d828 relayoutBoundary=up5 OVERFLOWING:
  parentData: offset=Offset(0.0, 28.0) (can use size)
  constraints: BoxConstraints(0.0<=w<=320.0, 0.0<=h<=133.2)
  size: Size(320.0, 133.2)
  direction: vertical
  mainAxisAlignment: start
  mainAxisSize: min
  crossAxisAlignment: center
  verticalDirection: down
  spacing: 0.0
◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤
═════════════════════════════════════════════════════════════════

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///[copia QA]/test/proximas_telas_visual_test.dart:269:9)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1059:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///[copia QA]/test/proximas_telas_visual_test.dart line 269
The test description was:
  chat: chat encerrado
Test failed. See exception logs above.
The test description was: chat: chat encerrado
```

## Escolher destino filtra campi desde uma letra e so busca enderecos com tres

Fonte: `frontend/test/selecionar_destino_visual_test.dart`. Estado da evidencia: `BLOQUEADO`. Runner: `FALHOU`.

Assert de 499/500 ms depende de relogio controlado; frames em tempo real ultrapassam a janela. Teste unitario deterministico anterior passou.

```text
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: empty
  Actual: ['unesp VETERINARIA']

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///[copia QA]/test/selecionar_destino_visual_test.dart:152:5)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1059:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///[copia QA]/test/selecionar_destino_visual_test.dart line 152
The test description was:
  filtra campi desde uma letra e so busca enderecos com tres
Test failed. See exception logs above.
The test description was: filtra campi desde uma letra e so busca enderecos com tres
```

## Recuperacao no aparelho seta fica na barra superior e nao acompanha a rolagem

Fonte: `frontend/test/recuperacao_visual_protecoes_test.dart`. Estado da evidencia: `BLOQUEADO`. Runner: `FALHOU`.

Coordenada absoluta pressupoe barra de status ausente; no caso adicional, MediaQuery foi lido apos SafeArea consumir padding. A assercao de nao se mover durante rolagem passou no teste original antes do limiar absoluto.

```text
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: a value less than or equal to <24>
  Actual: <78.0>
   Which: is not a value less than or equal to <24>

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///[copia QA]/test/recuperacao_visual_protecoes_test.dart:130:5)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1059:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///[copia QA]/test/recuperacao_visual_protecoes_test.dart line 130
The test description was:
  seta fica na barra superior e nao acompanha a rolagem
Test failed. See exception logs above.
The test description was: seta fica na barra superior e nao acompanha a rolagem
```

## Recorte CNH no aparelho recorte deitado com fonte ampliada mantem foto e cantos utilizaveis

Fonte: `frontend/test/recortar_cnh_test.dart`. Estado da evidencia: `BLOQUEADO`. Runner: `FALHOU`.

Limiar de 160 de preview em viewport sintetico retendo insets nativos nao permite concluir defeito funcional. Na rodada final, orientacao deitada fisica, quatro cantos e confirmacao do recorte passaram.

```text
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: a value greater than or equal to <160>
  Actual: <118.0>
   Which: is not a value greater than or equal to <160>

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///[copia QA]/test/recortar_cnh_test.dart:85:7)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1059:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///[copia QA]/test/recortar_cnh_test.dart line 85
The test description was:
  recorte deitado com fonte ampliada mantem foto e cantos utilizaveis
Test failed. See exception logs above.
The test description was: recorte deitado com fonte ampliada mantem foto e cantos utilizaveis
```

## Encontro sem GPS endereco atrasado do GPS nao substitui um encontro escolhido na pesquisa

Fonte: `frontend/test/mapa_encontro_sem_gps_test.dart`. Estado da evidencia: `BLOQUEADO`. Runner: `FALHOU`.

O mock usa flutter.baseflow.com/geolocator, mas o plugin Android instalado registra flutter.baseflow.com/geolocator_android. Nao comprovada a variante sintetica de GPS pretendida.

```text
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following StateError was thrown running a test:
Bad state: No element

When the exception was thrown, this was the stack:
#0      Iterable.single (dart:core/iterable.dart:694:25)
#1      WidgetController.widget (package:flutter_test/src/controller.dart:808:30)
#2      main.<anonymous closure>.<anonymous closure> (file:///[copia QA]/test/mapa_encontro_sem_gps_test.dart:82:18)
<asynchronous suspension>
#3      executar (file:///[copia QA]/test/qa_http_aparelho.dart:14:12)
<asynchronous suspension>
#4      main.<anonymous closure> (file:///[copia QA]/test/mapa_encontro_sem_gps_test.dart:68:7)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1059:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

The test description was:
  endereco atrasado do GPS nao substitui um encontro escolhido na pesquisa
Test failed. See exception logs above.
The test description was: endereco atrasado do GPS nao substitui um encontro escolhido na pesquisa
```

## Encontro sem GPS mapa permite escolher encontro manualmente com GPS desativado

Fonte: `frontend/test/mapa_encontro_sem_gps_test.dart`. Estado da evidencia: `BLOQUEADO`. Runner: `PASSOU`.

O mock usa flutter.baseflow.com/geolocator, mas o plugin Android instalado registra flutter.baseflow.com/geolocator_android. Nao comprovada a variante sintetica de GPS pretendida.

```text

```

## Encontro sem GPS mapa permite escolher encontro manualmente com GPS negado

Fonte: `frontend/test/mapa_encontro_sem_gps_test.dart`. Estado da evidencia: `BLOQUEADO`. Runner: `PASSOU`.

O mock usa flutter.baseflow.com/geolocator, mas o plugin Android instalado registra flutter.baseflow.com/geolocator_android. Nao comprovada a variante sintetica de GPS pretendida.

```text

```

## Encontro sem GPS mapa permite escolher encontro manualmente com GPS lento

Fonte: `frontend/test/mapa_encontro_sem_gps_test.dart`. Estado da evidencia: `BLOQUEADO`. Runner: `FALHOU`.

O mock usa flutter.baseflow.com/geolocator, mas o plugin Android instalado registra flutter.baseflow.com/geolocator_android. Nao comprovada a variante sintetica de GPS pretendida.

```text
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: <1>
  Actual: <0>

When the exception was thrown, this was the stack:
#4      main.<anonymous closure>.<anonymous closure> (file:///[copia QA]/test/mapa_encontro_sem_gps_test.dart:146:15)
<asynchronous suspension>
#5      executar (file:///[copia QA]/test/qa_http_aparelho.dart:14:12)
<asynchronous suspension>
#6      main.<anonymous closure> (file:///[copia QA]/test/mapa_encontro_sem_gps_test.dart:136:7)
<asynchronous suspension>
#7      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#8      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1059:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///[copia QA]/test/mapa_encontro_sem_gps_test.dart line 146
The test description was:
  mapa permite escolher encontro manualmente com GPS lento
Test failed. See exception logs above.
The test description was: mapa permite escolher encontro manualmente com GPS lento
```

## REPRO: chat carrega sem overflow em tela pequena encerrada=false

Fonte: `harness/revisao_aparelho_test.dart`. Estado da evidencia: `FALHOU`. Runner: `FALHOU`.



```text
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: null
  Actual: FlutterError:<A RenderFlex overflowed by 13 pixels on the bottom.>
Carregamento deve caber antes de a resposta chegar

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///[copia QA]/integration_test/conferencia_final_test.dart:53:7)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1059:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///[copia QA]/integration_test/conferencia_final_test.dart line 53
The test description was:
  REPRO: chat carrega sem overflow em tela pequena encerrada=false
Test failed. See exception logs above.
The test description was: REPRO: chat carrega sem overflow em tela pequena encerrada=false
```

## REPRO: chat carrega sem overflow em tela pequena encerrada=true

Fonte: `harness/revisao_aparelho_test.dart`. Estado da evidencia: `FALHOU`. Runner: `FALHOU`.



```text
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: null
  Actual: FlutterError:<A RenderFlex overflowed by 24 pixels on the bottom.>
Carregamento deve caber antes de a resposta chegar

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///[copia QA]/integration_test/conferencia_final_test.dart:53:7)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1059:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///[copia QA]/integration_test/conferencia_final_test.dart line 53
The test description was:
  REPRO: chat carrega sem overflow em tela pequena encerrada=true
Test failed. See exception logs above.
The test description was: REPRO: chat carrega sem overflow em tela pequena encerrada=true
```

## NATIVO UI: voltar na recuperacao respeita area segura e nao rola

Fonte: `harness/conferencia_final_test.dart`. Estado da evidencia: `BLOQUEADO`. Runner: `FALHOU`.

Coordenada absoluta pressupoe barra de status ausente; no caso adicional, MediaQuery foi lido apos SafeArea consumir padding. A assercao de nao se mover durante rolagem passou no teste original antes do limiar absoluto.

```text
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: a value less than or equal to <24.0>
  Actual: <41.0>
   Which: is not a value less than or equal to <24.0>

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///[copia QA]/integration_test/conferencia_final_test.dart:94:5)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1059:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///[copia QA]/integration_test/conferencia_final_test.dart line 94
The test description was:
  NATIVO UI: voltar na recuperacao respeita area segura e nao rola
Test failed. See exception logs above.
The test description was: NATIVO UI: voltar na recuperacao respeita area segura e nao rola
```

