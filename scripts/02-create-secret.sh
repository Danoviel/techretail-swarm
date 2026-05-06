#!/bin/sh
# ============================================================================
# 02 - Crear el Docker Secret para la BD
# ----------------------------------------------------------------------------
# Ejecuta SOLO en el manager. Los secrets se distribuyen automaticamente
# a los nodos donde corra el servicio que los necesita (cifrados en transito
# y en reposo, montados como tmpfs en /run/secrets/).
# ============================================================================

set -e

PASSWORD="${1:-MiPasswordSegura123}"

echo ">>> Creando secret 'db_password'..."
echo -n "$PASSWORD" | docker secret create db_password -

echo ""
echo ">>> Secret creado. Verifica con:"
echo "    docker secret ls"
echo ""
echo ">>> Listo para desplegar el stack (correr 03-deploy.sh)"
