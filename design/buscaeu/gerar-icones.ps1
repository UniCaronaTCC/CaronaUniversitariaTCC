$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

# Conversão de formato e tamanhos do desenho aprovado, sem dependências extras.
Add-Type -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
public static class MarcaBuscaEu {
    public static Bitmap Extrair(Bitmap imagem) {
        var resultado = new Bitmap(imagem.Width, imagem.Height, PixelFormat.Format32bppArgb);
        for (int y = 0; y < imagem.Height; y++) {
            for (int x = 0; x < imagem.Width; x++) {
                var pixel = imagem.GetPixel(x, y);
                double cobertura = Math.Max(0, Math.Min(1, (pixel.G - 22.0) / 233.0));
                int alfa = cobertura < 0.08 ? 0 : cobertura > 0.97 ? 255 : (int)Math.Round(cobertura * 255);
                resultado.SetPixel(x, y, Color.FromArgb(alfa, 255, 255, 255));
            }
        }
        return resultado;
    }
    public static Rectangle Limites(Bitmap imagem) {
        int esquerda = imagem.Width, topo = imagem.Height, direita = 0, baixo = 0;
        for (int y = 0; y < imagem.Height; y++) {
            for (int x = 0; x < imagem.Width; x++) {
                if (imagem.GetPixel(x, y).A < 128) continue;
                esquerda = Math.Min(esquerda, x); topo = Math.Min(topo, y);
                direita = Math.Max(direita, x); baixo = Math.Max(baixo, y);
            }
        }
        if (esquerda >= direita || topo >= baixo) throw new Exception("Símbolo não encontrado.");
        return Rectangle.FromLTRB(esquerda, topo, direita + 1, baixo + 1);
    }
}
'@ -ReferencedAssemblies System.Drawing

$raizProjeto = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$origem = [System.Drawing.Bitmap]::new((Join-Path $PSScriptRoot 'icone-gerado.png'))
$marca = [MarcaBuscaEu]::Extrair($origem)
$limitesMarca = [MarcaBuscaEu]::Limites($marca)
$roxo = [System.Drawing.ColorTranslator]::FromHtml('#8F16D9')

function Exportar-Icone {
    param([string]$Caminho, [int]$Lado, [int]$AlturaMarca, [string]$Fundo = 'roxo')
    $tipoPixel = if ($Fundo -eq 'roxo') {
        [System.Drawing.Imaging.PixelFormat]::Format24bppRgb
    } else {
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    }
    $imagem = [System.Drawing.Bitmap]::new($Lado, $Lado, $tipoPixel)
    $grafico = [System.Drawing.Graphics]::FromImage($imagem)
    try {
        $grafico.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $grafico.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $grafico.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $grafico.Clear([System.Drawing.Color]::Transparent)
        if ($Fundo -eq 'roxo') { $grafico.Clear($roxo) }
        if ($Fundo -eq 'arredondado') {
            $contorno = [System.Drawing.Drawing2D.GraphicsPath]::new()
            $diametro = [single]($Lado * 0.40)
            $limite = [single]($Lado - 1)
            $contorno.AddArc(0, 0, $diametro, $diametro, 180, 90)
            $contorno.AddArc(($limite - $diametro), 0, $diametro, $diametro, 270, 90)
            $contorno.AddArc(($limite - $diametro), ($limite - $diametro), $diametro, $diametro, 0, 90)
            $contorno.AddArc(0, ($limite - $diametro), $diametro, $diametro, 90, 90)
            $contorno.CloseFigure()
            $pincel = [System.Drawing.SolidBrush]::new($roxo)
            $grafico.FillPath($pincel, $contorno)
            $pincel.Dispose()
            $contorno.Dispose()
        }
        $larguraMarca = $AlturaMarca * $limitesMarca.Width / $limitesMarca.Height
        $destino = [System.Drawing.RectangleF]::new(
            (($Lado - $larguraMarca) / 2), (($Lado - $AlturaMarca) / 2), $larguraMarca, $AlturaMarca
        )
        $grafico.DrawImage($marca, $destino, $limitesMarca, [System.Drawing.GraphicsUnit]::Pixel)
        $pasta = Split-Path -Parent $Caminho
        [System.IO.Directory]::CreateDirectory($pasta) | Out-Null
        $imagem.Save($Caminho, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $grafico.Dispose()
        $imagem.Dispose()
    }
}

try {
    Exportar-Icone (Join-Path $PSScriptRoot 'icone-buscaeu.png') 1024 640
    Exportar-Icone (Join-Path $PSScriptRoot 'simbolo-buscaeu-branco.png') 1024 640 'transparente'
    $recursosAndroid = Join-Path $raizProjeto 'frontend/android/app/src/main/res'
    foreach ($densidade in @{'mdpi'=48; 'hdpi'=72; 'xhdpi'=96; 'xxhdpi'=144; 'xxxhdpi'=192}.GetEnumerator()) {
        Exportar-Icone (Join-Path $recursosAndroid "mipmap-$($densidade.Key)/ic_launcher.png") $densidade.Value ([int]($densidade.Value * 0.625)) 'arredondado'
    }
    # Área segura do adaptive icon: símbolo com 56 dp em um plano de 108 dp.
    Exportar-Icone (Join-Path $recursosAndroid 'drawable-nodpi/ic_launcher_foreground.png') 432 224 'transparente'

    $pastaIos = Join-Path $raizProjeto 'frontend/ios/Runner/Assets.xcassets/AppIcon.appiconset'
    $catalogoIos = Get-Content -LiteralPath (Join-Path $pastaIos 'Contents.json') -Raw | ConvertFrom-Json
    $arquivosGerados = @{}
    foreach ($item in $catalogoIos.images) {
        if ($arquivosGerados.ContainsKey($item.filename)) { continue }
        $tamanho = [double]::Parse($item.size.Split('x')[0], [System.Globalization.CultureInfo]::InvariantCulture)
        $escala = [double]::Parse($item.scale.TrimEnd('x'), [System.Globalization.CultureInfo]::InvariantCulture)
        $pixels = [int][Math]::Round($tamanho * $escala)
        Exportar-Icone (Join-Path $pastaIos $item.filename) $pixels ([int]($pixels * 0.625))
        $arquivosGerados[$item.filename] = $true
    }
    Write-Output 'Ícones BuscaEu exportados para Android, iOS e arquivos para compartilhar.'
} finally {
    $marca.Dispose()
    $origem.Dispose()
}
