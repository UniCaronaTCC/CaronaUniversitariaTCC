# BuscaEu — aplicativo Flutter

Interface móvel em **Flutter e Dart**, integrada à API NestJS e aos serviços Supabase.

[Voltar ao projeto](../README.md) · [Guia da Parte 4](../docs/PARTE_4_IMPLEMENTACAO.md)

## Estrutura

| Pasta em `lib/` | Conteúdo |
|---|---|
| `auth/` | Telas de acesso |
| `home/` | Telas e fluxos principais |
| `services/` | Comunicação HTTP, sessão, integrações e memórias de dados |
| `models/` | Modelos utilizados pelo aplicativo |
| `widgets/` | Componentes reutilizáveis |
| `config/` | Tema e configurações de API e Supabase |
| `navigation/` | Navegação principal |
| `inicializacao/` | Abertura e inicialização dos serviços |

O ponto de entrada é [main.dart](lib/main.dart). Recursos visuais estão em `assets/`; os testes ficam em `test/`.

## Executar

Instale Flutter com Dart compatível com [pubspec.yaml](pubspec.yaml) (Dart 3.10.8 ou superior dentro da série 3), além das ferramentas da plataforma escolhida.

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

`10.0.2.2` alcança o computador a partir do emulador Android. Em um celular físico, informe o endereço da API acessível por esse aparelho.

As configurações estão em [api_config.dart](lib/config/api_config.dart) e [supabase_config.dart](lib/config/supabase_config.dart). Também são aceitos `SUPABASE_URL` e `SUPABASE_PUBLISHABLE_KEY` por `--dart-define`. Use somente a chave publicável no cliente; chaves secretas de servidor e credenciais do banco não pertencem ao aplicativo.

## Verificar e gerar APK

```bash
flutter test
flutter analyze
flutter build apk --debug --dart-define=API_BASE_URL=https://api.exemplo.com
```

Substitua o endereço de exemplo pela API da equipe. O APK será gerado em `build/app/outputs/flutter-apk/app-debug.apk`.

Testes de widgets e services usam dados e dependências controlados. Câmera, OCR, permissões de localização, acompanhamento e integração com a API também precisam de verificação no dispositivo.

## Exemplo para a Parte 4

O [painel de solicitações](lib/widgets/painel_solicitacoes_carona.dart) chama [SolicitacaoService](lib/services/solicitacao_service.dart), que envia o aceite à API com o token da sessão. A resposta retorna para o painel, que mostra a mensagem e atualiza os dados.

O [guia de implementação](../docs/PARTE_4_IMPLEMENTACAO.md) acompanha essa operação até a transação no PostgreSQL e indica os testes relacionados.
