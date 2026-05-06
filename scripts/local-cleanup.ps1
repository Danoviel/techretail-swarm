# ============================================================================
# TechRetail - Limpieza completa del setup local
# ----------------------------------------------------------------------------
# Borra los 3 nodos DinD y la red. Usar al terminar la demo o si quieres
# rehacer todo desde cero.
# ============================================================================

$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host ">>> Eliminando nodos node1, node2, node3..." -ForegroundColor Yellow
foreach ($n in @("node1", "node2", "node3")) {
    docker rm -f $n 2>&1 | Out-Null
}

Write-Host ">>> Eliminando red 'swarm-net'..." -ForegroundColor Yellow
docker network rm swarm-net 2>&1 | Out-Null

Write-Host ""
Write-Host ">>> Limpieza completa." -ForegroundColor Green
Write-Host ">>> Para volver a levantar el cluster: .\scripts\local-setup.ps1"
Write-Host ""
