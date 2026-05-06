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

$ErrorActionPreference = "Continue"

function Wait-DockerDaemon {
    param(
        [string]$NodeName,
        [int]$TimeoutSec = 90
    )
    $start = Get-Date
    while (((Get-Date) - $start).TotalSeconds -lt $TimeoutSec) {
        docker exec $NodeName docker info 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            return $true
        }
        Start-Sleep -Seconds 2
        Write-Host "    ... daemon en $NodeName aun no responde, reintentando" -ForegroundColor DarkGray
    }
    return $false
}

function Assert-Success {
    param([string]$Step)
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "FALLO en: $Step (exit code $LASTEXITCODE)" -ForegroundColor Red
        Write-Host "Aborta. Para limpiar el estado parcial: .\scripts\local-cleanup.ps1" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "==============================================================="  -ForegroundColor Cyan
Write-Host " TechRetail - Setup local del cluster Docker Swarm" -ForegroundColor Cyan
Write-Host "==============================================================="  -ForegroundColor Cyan
Write-Host ""

# ---- 0) Limpiar estado previo si existe ----
Write-Host ">>> Limpiando nodos previos si existen..." -ForegroundColor Yellow
foreach ($n in @("node1", "node2", "node3")) {
    docker rm -f $n 2>&1 | Out-Null
}
docker network rm swarm-net 2>&1 | Out-Null

# ---- 1) Red bridge para los 3 nodos ----
Write-Host ">>> Creando red 'swarm-net'..." -ForegroundColor Yellow
docker network create swarm-net | Out-Null
Assert-Success "crear red swarm-net"

# ---- 2) Levantar los 3 nodos DinD ----
Write-Host ">>> Levantando node1 (manager) - expone :80 y :8080 al host..." -ForegroundColor Yellow
docker run -d --privileged --name node1 -h node1 `
    --network swarm-net `
    -e DOCKER_TLS_CERTDIR="" `
    -p 80:80 -p 8080:8080 `
    docker:dind | Out-Null
Assert-Success "crear node1"

Write-Host ">>> Levantando node2 (worker)..." -ForegroundColor Yellow
docker run -d --privileged --name node2 -h node2 `
    --network swarm-net `
    -e DOCKER_TLS_CERTDIR="" `
    docker:dind | Out-Null
Assert-Success "crear node2"

Write-Host ">>> Levantando node3 (worker)..." -ForegroundColor Yellow
docker run -d --privileged --name node3 -h node3 `
    --network swarm-net `
    -e DOCKER_TLS_CERTDIR="" `
    docker:dind | Out-Null
Assert-Success "crear node3"

# ---- 3) Esperar a que CADA daemon interno este listo (polling activo) ----
Write-Host ""
Write-Host ">>> Esperando a que los Docker daemons internos esten listos..." -ForegroundColor Yellow
foreach ($n in @("node1", "node2", "node3")) {
    Write-Host "    Esperando daemon en $n..."
    if (-not (Wait-DockerDaemon -NodeName $n -TimeoutSec 90)) {
        Write-Host "FALLO: el daemon en $n no respondio en 90s" -ForegroundColor Red
        Write-Host "Logs del nodo:" -ForegroundColor Red
        docker logs $n --tail 20
        exit 1
    }
    Write-Host "    OK $n esta listo" -ForegroundColor Green
}

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
Assert-Success "swarm init en node1"

# ---- 6) Obtener token y unir workers ----
$token = (docker exec node1 docker swarm join-token worker -q).Trim()
if ([string]::IsNullOrEmpty($token)) {
    Write-Host "FALLO: no se pudo obtener el join token" -ForegroundColor Red
    exit 1
}
Write-Host ">>> Token de worker obtenido (primeros 20 chars): $($token.Substring(0, [Math]::Min(20, $token.Length)))..." -ForegroundColor DarkGray

Write-Host ">>> Uniendo node2 al swarm..." -ForegroundColor Yellow
docker exec node2 docker swarm join --token $token "${ip1}:2377" | Out-Null
Assert-Success "swarm join en node2"

Write-Host ">>> Uniendo node3 al swarm..." -ForegroundColor Yellow
docker exec node3 docker swarm join --token $token "${ip1}:2377" | Out-Null
Assert-Success "swarm join en node3"

# ---- 7) Instalar git en node1 (no viene en docker:dind) ----
Write-Host ">>> Instalando git en node1 (para clonar el repo)..." -ForegroundColor Yellow
docker exec node1 apk add --no-cache git 2>&1 | Out-Null
Assert-Success "instalar git en node1"

# ---- 8) Clonar el repo dentro de node1 ----
Write-Host ">>> Clonando el repositorio en node1..." -ForegroundColor Yellow
docker exec node1 sh -c "rm -rf /techretail-swarm && git clone https://github.com/Danoviel/techretail-swarm.git /techretail-swarm" 2>&1 | Out-Null
Assert-Success "clonar repo en node1"

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
