# ============================================================================
# TechRetail - Setup local con Docker Desktop
# ----------------------------------------------------------------------------
# Levanta 3 contenedores Docker-in-Docker (DinD) que simulan un cluster Swarm
# en tu PC. Equivalente a usar 3 nodos en Play with Docker, pero local.
#
# Requisitos:
#   - Docker Desktop instalado y corriendo (icono ballena verde en bandeja)
#   - ~3 GB de RAM libres
#
# Uso:
#   PS> .\scripts\local-setup.ps1
# ============================================================================

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "==============================================================="  -ForegroundColor Cyan
Write-Host " TechRetail - Setup local del cluster Docker Swarm" -ForegroundColor Cyan
Write-Host "==============================================================="  -ForegroundColor Cyan
Write-Host ""

# ---- 0) Limpiar estado previo si existe ----
Write-Host ">>> Limpiando nodos previos si existen..." -ForegroundColor Yellow
docker rm -f node1 node2 node3 2>$null | Out-Null
docker network rm swarm-net 2>$null | Out-Null

# ---- 1) Red bridge para los 3 nodos ----
Write-Host ">>> Creando red 'swarm-net'..." -ForegroundColor Yellow
docker network create swarm-net | Out-Null

# ---- 2) Levantar los 3 nodos DinD ----
Write-Host ">>> Levantando node1 (manager) - expone :80 y :8080 al host..." -ForegroundColor Yellow
docker run -d --privileged --name node1 -h node1 `
    --network swarm-net `
    -e DOCKER_TLS_CERTDIR="" `
    -p 80:80 -p 8080:8080 `
    docker:dind | Out-Null

Write-Host ">>> Levantando node2 (worker)..." -ForegroundColor Yellow
docker run -d --privileged --name node2 -h node2 `
    --network swarm-net `
    -e DOCKER_TLS_CERTDIR="" `
    docker:dind | Out-Null

Write-Host ">>> Levantando node3 (worker)..." -ForegroundColor Yellow
docker run -d --privileged --name node3 -h node3 `
    --network swarm-net `
    -e DOCKER_TLS_CERTDIR="" `
    docker:dind | Out-Null

# ---- 3) Esperar a que los daemons internos arranquen ----
Write-Host ">>> Esperando 12s a que los Docker daemons internos arranquen..." -ForegroundColor Yellow
Start-Sleep -Seconds 12

# ---- 4) IPs internas en la red swarm-net ----
$ip1 = (docker exec node1 hostname -i).Trim()
$ip2 = (docker exec node2 hostname -i).Trim()
$ip3 = (docker exec node3 hostname -i).Trim()
Write-Host ""
Write-Host ">>> IPs internas:" -ForegroundColor Green
Write-Host "    node1 = $ip1 (manager)"
Write-Host "    node2 = $ip2"
Write-Host "    node3 = $ip3"
Write-Host ""

# ---- 5) Inicializar Swarm en node1 ----
Write-Host ">>> Inicializando Swarm en node1..." -ForegroundColor Yellow
docker exec node1 docker swarm init --advertise-addr $ip1 | Out-Null

# ---- 6) Unir workers ----
$token = (docker exec node1 docker swarm join-token worker -q).Trim()

Write-Host ">>> Uniendo node2 al swarm..." -ForegroundColor Yellow
docker exec node2 docker swarm join --token $token "${ip1}:2377" | Out-Null

Write-Host ">>> Uniendo node3 al swarm..." -ForegroundColor Yellow
docker exec node3 docker swarm join --token $token "${ip1}:2377" | Out-Null

# ---- 7) Instalar git en node1 (no viene en docker:dind) ----
Write-Host ">>> Instalando git en node1 (para clonar el repo)..." -ForegroundColor Yellow
docker exec node1 apk add --no-cache git | Out-Null

# ---- 8) Clonar el repo dentro de node1 ----
Write-Host ">>> Clonando el repositorio en node1..." -ForegroundColor Yellow
docker exec node1 sh -c "rm -rf /techretail-swarm && git clone https://github.com/Danoviel/techretail-swarm.git /techretail-swarm" | Out-Null

# ---- 9) Estado final ----
Write-Host ""
Write-Host "==============================================================="  -ForegroundColor Cyan
Write-Host " Cluster listo. Estado de los nodos:" -ForegroundColor Cyan
Write-Host "==============================================================="  -ForegroundColor Cyan
docker exec node1 docker node ls

Write-Host ""
Write-Host ">>> Siguientes pasos:" -ForegroundColor Green
Write-Host ""
Write-Host "  1) Entrar al manager:" -ForegroundColor White
Write-Host "       docker exec -it node1 sh" -ForegroundColor Cyan
Write-Host ""
Write-Host "  2) Ir al proyecto y desplegar:" -ForegroundColor White
Write-Host "       cd /techretail-swarm" -ForegroundColor Cyan
Write-Host "       chmod +x scripts/*.sh" -ForegroundColor Cyan
Write-Host "       ./scripts/02-create-secret.sh" -ForegroundColor Cyan
Write-Host "       ./scripts/03-deploy.sh" -ForegroundColor Cyan
Write-Host ""
Write-Host "  3) Acceder desde tu navegador:" -ForegroundColor White
Write-Host "       Frontend  -> http://localhost" -ForegroundColor Cyan
Write-Host "       Visualizer -> http://localhost:8080" -ForegroundColor Cyan
Write-Host ""
Write-Host "  4) Cuando termines, limpiar todo:" -ForegroundColor White
Write-Host "       .\scripts\local-cleanup.ps1" -ForegroundColor Cyan
Write-Host ""
