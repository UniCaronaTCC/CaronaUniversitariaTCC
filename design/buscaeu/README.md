# Identidade visual BuscaEu

A proposta **3** foi escolhida: um B branco com uma rota entre dois pontos, sobre o roxo principal do aplicativo (`#8F16D9`). Ela já substitui os ícones do Android e do iOS.

## Arquivos finais

- `icone-buscaeu.png`: ícone de 1024 × 1024, com fundo roxo opaco, para salvar e compartilhar.
- `simbolo-buscaeu-branco.png`: símbolo branco com transparência, também em 1024 × 1024.
- `icone-gerado.png`: desenho de origem para reproduzir as exportações.
- `gerar-icones.ps1`: exporta os arquivos usando o Windows PowerShell e System.Drawing, sem instalar dependências. Executar na raiz do projeto: `powershell.exe -NoProfile -File design/buscaeu/gerar-icones.ps1`.

Android: cinco tamanhos tradicionais, ícone adaptativo com fundo e símbolo separados, e versão monocromática para ícones temáticos. O símbolo fica na área segura do ícone adaptativo. iOS: todos os tamanhos do catálogo existente, com fundo opaco e sem cantos pré-recortados.

O nome exibido foi alterado no Android, no iOS e no título do Flutter. Os identificadores internos foram preservados para manter a continuidade da instalação existente. O nome padrão do arquivo produzido pelo Flutter continua sendo `app-debug.apk` ou `app-release.apk`; uma cópia para distribuição pode se chamar `BuscaEu.apk`.

## Estudos anteriores

As três propostas em `propostas-logo.png` usam roxo, branco e preto:

1. Pino com rota: busca, localização e encontro.
2. Carro com duas pessoas: carona compartilhada.
3. Letra B com rota: associação direta ao nome BuscaEu.

## Geração das propostas

Ferramenta: geração de imagens integrada, usando a habilidade `imagegen`.

Prompt utilizado:

> Use case: logo-brand. Create one polished landscape presentation board showing THREE DISTINCT logo proposals for "BuscaEu", a Brazilian university carpool app. Number each proposal 1, 2, 3. Exact brand spelling: BuscaEu. Palette strictly primary purple #8F16D9, white, near black, optional very light purple tint. Flat vector-like graphic design, strong geometric curves, warm approachable yet professional, high contrast and recognizable at tiny mobile app icon size. Clean off-white background, three equal columns, ample whitespace. Each column has one large purple rounded-square app icon with a bold simple white symbol, below it the same symbol with the wordmark BuscaEu in a clean modern rounded sans serif. Concept 1: a distinctive location pin whose negative space forms a winding route and two meeting endpoints. Concept 2: a friendly car front combined with two simple passenger shapes, simplified cohesive silhouette. Concept 3: bold letter B formed from a continuous curved route and two stops. Make each mark visually coherent, optically centered, few elements, thick shapes. Do not include slogans, no gradients, no 3D, no mockup objects, no photographs, no fine line details, no other brand references. This is a design exploration board, not yet production icons.

## Preparação da opção escolhida

Ferramenta: geração de imagens integrada, seguida de conversão determinística de cores, transparência, margens e tamanhos no script de exportação. Uma tentativa de extração direta com transparência apresentou artefatos e foi descartada.

Prompt final, tendo `propostas-logo.png` como referência:

> Use case: precise-object-edit. Edit target is the supplied board. Extract ONLY concept 3, the RIGHTMOST selected white B with winding route and two circular endpoints. Preserve exact silhouette, endpoint placement and negative-space route from that selected reference. Output one perfectly clean production app icon, square canvas, SOLID OPAQUE PURPLE #8F16D9 filling the entire canvas edge to edge including all four corners (not a rounded rectangle). Center the bold WHITE B symbol at about 62% of canvas height with ample uniform padding. All spaces outside and inside B route must be flat solid purple; B must be flat pure white. Absolutely NO textures, no speckles, no transparency, no black anywhere, no distressing, no gradient, no shadows, no background checkerboard, no number 3, no wordmark. Smooth crisp geometric contours and continuous clean purple S-curve cutout with a clean purple circle at each endpoint. Faithful asset extraction, not a redesign. Exactly two solid colors: white and purple.
