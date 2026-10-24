param(
  [Parameter(Mandatory = $true)][string]$SourceDirectory,
  [Parameter(Mandatory = $true)][string]$DestinationZip
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $SourceDirectory -PathType Container)) {
  throw "Windows release directory not found: $SourceDirectory"
}

$destinationDirectory = Split-Path -Parent $DestinationZip
New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
if (Test-Path -LiteralPath $DestinationZip) {
  Remove-Item -LiteralPath $DestinationZip -Force
}

Compress-Archive `
  -Path (Join-Path $SourceDirectory '*') `
  -DestinationPath $DestinationZip `
  -CompressionLevel Optimal
