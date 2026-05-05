#!/usr/bin/env bash
# ============================================================================
# 01 - Inicializar Docker Swarm
# ----------------------------------------------------------------------------
# Ejecuta este script EN EL NODO MANAGER (node1 en Play with Docker).
#
# En PWD la IP del nodo aparece arriba del terminal (ej: 192.168.0.13).
# Copia esa IP y pasala como argumento, o el script la detecta automatico.
# ============================================================================

set -e

# Detectar IP automaticamente (interfaz eth0 en PWD)
MANAGER_IP="${1:-$(hostname -i | awk '{print $1}')}"

echo ">>> Inicializando Swarm en $MANAGER_IP"
docker swarm init --advertise-addr "$MANAGER_IP"

echo ""
echo "========================================================================"
echo ">>> COPIA el siguiente comando y EJECUTALO en cada nodo Worker:"
echo "========================================================================"
docker swarm join-token worker | grep "docker swarm join"
echo "========================================================================"
echo ""
echo ">>> Una vez los workers se hayan unido, verifica con:"
echo "    docker node ls"
