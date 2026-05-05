#!/usr/bin/env bash
# ============================================================================
# 04 - Demostracion de escalado dinamico
# ----------------------------------------------------------------------------
# El requerimiento 3.3 pide demostrar que se pueden escalar las replicas
# en caliente. Este script lo hace en dos pasos para que se aprecie en el
# visualizer y en el video.
# ============================================================================

set -e

STACK_NAME="${1:-techretail}"

echo ">>> Estado actual del frontend:"
docker service ps "${STACK_NAME}_frontend" --filter "desired-state=running"

echo ""
echo ">>> Escalando frontend de 3 a 5 replicas..."
docker service scale "${STACK_NAME}_frontend"=5

echo ""
echo ">>> Esperando 5s para que Swarm distribuya las nuevas replicas..."
sleep 5

echo ""
echo ">>> Nuevo estado del frontend:"
docker service ps "${STACK_NAME}_frontend" --filter "desired-state=running"

echo ""
echo ">>> Escalando backend de 2 a 4 replicas..."
docker service scale "${STACK_NAME}_backend"=4

sleep 5

echo ""
echo ">>> Nuevo estado del backend:"
docker service ps "${STACK_NAME}_backend" --filter "desired-state=running"

echo ""
echo ">>> Refresca el visualizer (puerto 8080) para ver las replicas distribuidas."
echo ">>> Para volver al estado original:"
echo "    docker service scale ${STACK_NAME}_frontend=3 ${STACK_NAME}_backend=2"
