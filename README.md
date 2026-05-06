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

## Despliegue paso a paso

> **Nota:** Play with Docker fue deprecated en marzo de 2026. Este proyecto se despliega ahora con **Docker Desktop local** usando contenedores Docker-in-Docker (DinD) que simulan los 3 nodos del clúster.

### 1. Levantar el clúster local (1 comando)
Requisitos: Docker Desktop instalado y corriendo (icono ballena verde en bandeja).

```powershell
# Desde la raíz del proyecto, en PowerShell
.\scripts\local-setup.ps1
```

El script automáticamente:
- Crea una red `swarm-net` para los nodos
- Levanta 3 contenedores DinD (`node1` manager + `node2`/`node3` workers)
- Inicializa Swarm e une los workers
- Clona el repo dentro de `node1`
- Mapea los puertos `:80` y `:8080` del manager a tu máquina

### 2. Entrar al manager y desplegar
```powershell
docker exec -it node1 sh
```

Una vez dentro de node1:
```bash
cd /techretail-swarm
chmod +x scripts/*.sh
./scripts/02-create-secret.sh        # crea el secret de la BD
./scripts/03-deploy.sh               # despliega el stack
```

### 3. Verificar
```bash
docker stack services techretail   # 5 servicios, todos RUNNING
docker stack ps techretail         # En qué nodo está cada réplica
docker service logs techretail_backend
```

### 4. Acceder desde el navegador (en tu Windows)
- **Frontend:** http://localhost
- **Visualizer:** http://localhost:8080

### 5. Demo de escalado
```bash
# Aún dentro de node1
./scripts/04-scale-demo.sh
# Escala frontend 3→5 y backend 2→4
```
Refrescar el visualizer para ver las nuevas réplicas distribuyéndose entre los 3 nodos.

### 6. Limpieza completa
```powershell
# Desde tu PowerShell (afuera de node1)
.\scripts\local-cleanup.ps1
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
