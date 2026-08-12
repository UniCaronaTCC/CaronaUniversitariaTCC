param(
  [Parameter(Mandatory = $true)]
  [string]$ArquivoCsv,

  [string]$Saida = (Join-Path $PSScriptRoot '..\cargas\instituicoes_2024.sql')
)

if (-not (Test-Path -LiteralPath $ArquivoCsv)) {
  throw "Arquivo CSV nao encontrado: $ArquivoCsv"
}

function Formatar-TextoSql([string]$valor) {
  if ([string]::IsNullOrWhiteSpace($valor)) {
    return 'NULL'
  }

  return "'" + $valor.Trim().Replace("'", "''") + "'"
}

$registros = @(foreach ($item in Import-Csv -LiteralPath $ArquivoCsv -Delimiter ';' -Encoding Default) {
  $codigo = 0

  if (-not [int]::TryParse($item.CO_IES, [ref]$codigo)) {
    continue
  }

  $nome = Formatar-TextoSql $item.NO_IES
  $sigla = Formatar-TextoSql $item.SG_IES
  $municipio = Formatar-TextoSql $item.NO_MUNICIPIO_IES
  $uf = Formatar-TextoSql $item.SG_UF_IES

  "($codigo, $nome, $sigla, $municipio, $uf, TRUE)"
})

$linhas = [System.Collections.Generic.List[string]]::new()
$linhas.Add('-- Dados do Censo da Educacao Superior 2024 - Inep')
$linhas.Add('USE carona_universitaria;')
$linhas.Add('SET NAMES utf8mb4;')
$linhas.Add('')

for ($inicio = 0; $inicio -lt $registros.Count; $inicio += 500) {
  $fim = [Math]::Min($inicio + 499, $registros.Count - 1)
  $bloco = $registros[$inicio..$fim]

  $linhas.Add('INSERT INTO instituicoes')
  $linhas.Add('  (codigo_emec, nome, sigla, municipio, uf, ativa)')
  $linhas.Add('VALUES')
  $linhas.Add(($bloco -join ",`r`n") + ' AS novos')
  $linhas.Add('ON DUPLICATE KEY UPDATE')
  $linhas.Add('  nome = novos.nome,')
  $linhas.Add('  sigla = novos.sigla,')
  $linhas.Add('  municipio = novos.municipio,')
  $linhas.Add('  uf = novos.uf,')
  $linhas.Add('  ativa = TRUE;')
  $linhas.Add('')
}

[System.IO.File]::WriteAllLines(
  $Saida,
  $linhas,
  [System.Text.UTF8Encoding]::new($false)
)

Write-Output "$($registros.Count) instituicoes gravadas em $Saida"
