# TechRetail — Despliegue con Docker Swarm

Caso académico: orquestación de microservicios para una tienda online con Docker Swarm. El stack incluye frontend (nginx), backend (Node.js), base de datos (MySQL), cache (Redis) y un visualizador del clúster.

## Arquitectura

```
                       DOCKER SWARM CLUSTER
   ┌─────────────────────────────────────────────────────────┐
   │  Manager Node           Worker 1           Worker 2     │
   │  ┌───────────┐         ┌───────────┐     ┌───────────┐  │
   │  │ database  │         │ frontend  │     │ frontend  │  │
   │  │ visualizer│         │ backend   │     │ backend   │  │
   │  │ frontend  │         │ cache     │     │           │  │
   │  └───────────┘         └───────────┘     └───────────┘  │
   │         │                    │                  │       │
   │         └─── Red overlay (techretail_net) ──────┘       │
   └─────────────────────────────────────────────────────────┘
```

| Servicio    | Imagen                       | Réplicas | Función                       |
|-------------|------------------------------|----------|-------------------------------|
| frontend    | `nginx:alpine`               | 3        | Sirve la SPA y hace proxy /api|
| backend     | `node:18-alpine`             | 2        | API REST mínima (hostname)    |
| database    | `mysql:8`                    | 1 (mgr)  | Persistencia                  |
| cache       | `redis:7-alpine`             | 1        | Cache de consultas            |
| visualizer  | `dockersamples/visualizer`   | 1 (mgr)  | Dashboard del clúster :8080   |

## Estructura del proyecto

```
techretail-swarm/
├── docker-compose.yml          # Stack completo de Swarm
├── backend/
│   └── server.js               # API Node.js (sin dependencias)
├── frontend/
│   ├── nginx.conf              # Config de nginx (vía Docker Configs)
│   └── index.html              # SPA demo (vía Docker Configs)
├── secrets/
│   └── db_password.txt.example # Template (el real está gitignored)
├── scripts/
│   ├── 01-init-swarm.sh        # Inicializa el manager
│   ├── 02-create-secret.sh     # Crea el secret de la BD
│   ├── 03-deploy.sh            # Deploy del stack
│   ├── 04-scale-demo.sh        # Demo de escalado dinámico
│   └── 99-cleanup.sh           # Limpieza
├── capturas/                   # Screenshots del entregable
├── README.md                   # Este archivo
└── INFORME.md                  # Base del informe técnico (PDF)
```

## Despliegue paso a paso (Play with Docker)

### 1. Crear el clúster
1. Entrar a https://labs.play-with-docker.com/ (login con Docker Hub).
2. Click en **+ ADD NEW INSTANCE** tres veces → tendrás `node1`, `node2`, `node3`.
3. Cada nodo muestra su IP arriba del terminal (ej: `192.168.0.13`).

### 2. Subir el proyecto al manager
En `node1` (el manager):

```bash
git clone https://github.com/<TU_USUARIO>/techretail-swarm.git
cd techretail-swarm
chmod +x scripts/*.sh
```

### 3. Inicializar Swarm
**En `node1`:**
```bash
./scripts/01-init-swarm.sh
```
Copia el comando `docker swarm join --token SWMTKN-...` que imprime.

**En `node2` y `node3`:** pega ese comando.

**Verifica desde `node1`:**
```bash
docker node ls
```
Debe listar 3 nodos: 1 con `MANAGER STATUS = Leader`, 2 sin.

### 4. Crear el secret
```bash
./scripts/02-create-secret.sh
# o personalizado:
./scripts/02-create-secret.sh "MiPasswordSuperSegura"
```

### 5. Desplegar el stack
```bash
./scripts/03-deploy.sh
```

### 6. Verificar
- **Frontend:** click en el botón `80` arriba del terminal de `node1` → abre la SPA demo.
- **Visualizer:** click en el botón `8080` → ves los containers distribuidos en los 3 nodos.

```bash
docker stack services techretail   # 5 servicios, todos con réplicas en estado RUNNING
docker stack ps techretail         # En qué nodo está cada réplica
docker service logs techretail_backend   # Logs del backend
```

### 7. Demo de escalado
```bash
./scripts/04-scale-demo.sh
# Escala frontend 3→5 y backend 2→4
```
Refrescar el visualizer para ver las nuevas réplicas distribuyéndose.

### 8. Limpieza (opcional)
```bash
./scripts/99-cleanup.sh
```

## Uso de Secrets y Configs

**Docker Secrets** (datos sensibles, cifrados):
- `db_password` → montado en `/run/secrets/db_password` dentro de los containers de `backend` y `database`.

**Docker Configs** (archivos no sensibles, distribuidos por Swarm a todos los nodos):
- `nginx_conf` → `frontend/nginx.conf` montado en `/etc/nginx/nginx.conf`.
- `index_html` → `frontend/index.html` montado en `/usr/share/nginx/html/index.html`.
- `backend_server` → `backend/server.js` montado en `/app/server.js`.

> **Por qué Configs y no build de imagen:** evita tener que hacer push del código a Docker Hub para que los workers puedan correr el backend. Swarm distribuye los configs automáticamente.

## Demostración de alta disponibilidad

Para probar que el clúster sigue funcionando si un nodo cae:

```bash
# En node2 (worker), detener Docker:
sudo systemctl stop docker
# o desde el manager, marcar el nodo como drain:
docker node update --availability drain node2
```
Swarm reprograma las réplicas que estaban en ese nodo a los demás. Verifica con:
```bash
docker stack ps techretail
```

## Comandos útiles

```bash
# Estado general
docker node ls
docker stack ls
docker stack services techretail
docker stack ps techretail

# Escalado
docker service scale techretail_frontend=5
docker service scale techretail_backend=3

# Inspeccionar un servicio
docker service inspect techretail_backend --pretty

# Logs
docker service logs -f techretail_frontend

# Eliminar todo
docker stack rm techretail
docker secret rm db_password
docker swarm leave --force   # solo si quieres salir del swarm
```

## Notas

- **Play with Docker** corta la sesión a las 4 horas. Hacer todas las capturas y el video en una sola corrida.
- El `docker-compose.yml` usa `version: "3.8"` por compatibilidad con la plantilla del docente. En Docker moderno es opcional.
- El backend y la SPA se distribuyen vía **Docker Configs** — no hace falta build ni push a Docker Hub.

## Autor

David Carhuaz — Diseño y Desarrollo de Software
