$ErrorActionPreference = 'Stop'
Set-Location (Join-Path (Split-Path -Parent $PSScriptRoot) 'server')
dart run bin/preview.dart
