#!/bin/sh
# ============================================================================
# 99 - Limpieza completa del stack y del swarm
# ----------------------------------------------------------------------------
# Util al terminar la demo o si quieres rehacer todo desde cero.
# En PWD esto es opcional porque la sesion se borra a las 4 horas.
# ============================================================================

set -e

STACK_NAME="${1:-techretail}"

echo ">>> Eliminando stack '$STACK_NAME'..."
docker stack rm "$STACK_NAME" || true

echo ">>> Esperando 10s a que Swarm libere los recursos..."
sleep 10

echo ">>> Eliminando secret 'db_password'..."
docker secret rm db_password || true

echo ">>> Eliminando volumen db_data..."
docker volume rm "${STACK_NAME}_db_data" 2>/dev/null || true

echo ""
echo ">>> Estado final:"
docker stack ls
docker service ls
docker secret ls

echo ""
echo ">>> Para sacar este nodo del swarm (opcional):"
echo "    docker swarm leave --force"
