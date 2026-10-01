$ErrorActionPreference = 'Stop'
Push-Location (Join-Path $PSScriptRoot '../server')
try { dart run bin/firebase_worker.dart } finally { Pop-Location }
