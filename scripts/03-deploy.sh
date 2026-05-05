#!/usr/bin/env bash
# ============================================================================
# 03 - Desplegar el stack TechRetail
# ----------------------------------------------------------------------------
# Ejecuta en el manager, desde la raiz del proyecto (donde esta el compose).
# ============================================================================

set -e

STACK_NAME="${1:-techretail}"

echo ">>> Desplegando stack '$STACK_NAME'..."
docker stack deploy -c docker-compose.yml "$STACK_NAME"

echo ""
echo ">>> Esperando a que los servicios arranquen..."
sleep 8

echo ""
echo "========================================================================"
echo ">>> Estado de los servicios:"
echo "========================================================================"
docker stack services "$STACK_NAME"

echo ""
echo "========================================================================"
echo ">>> Distribucion de replicas en los nodos:"
echo "========================================================================"
docker stack ps "$STACK_NAME" --filter "desired-state=running"

echo ""
echo ">>> Stack desplegado. Acceso:"
echo "    Frontend:   http://<IP_MANAGER>/"
echo "    Visualizer: http://<IP_MANAGER>:8080/"
echo ""
echo ">>> Para ver logs en tiempo real:"
echo "    docker service logs -f ${STACK_NAME}_backend"
