# Informe Técnico — Despliegue de TechRetail con Docker Swarm

> **Curso:** [completar]
> **Docente:** [completar]
> **Estudiante(s):** David Carhuaz
> **Fecha:** [completar]

---

## 1. Resumen ejecutivo

TechRetail, empresa peruana de comercio electrónico, sufría caídas frecuentes y tiempos de respuesta lentos durante picos de tráfico. Como solución, se diseñó e implementó un clúster **Docker Swarm** con 3 nodos que orquesta cinco microservicios (frontend, backend, base de datos, cache y visualizador). El stack soporta escalado horizontal en caliente, alta disponibilidad mediante réplicas distribuidas y gestión segura de credenciales con Docker Secrets.

---

## 2. Caso de estudio

### 2.1 Problemática
- Caídas frecuentes en horas pico ("Buen Fin", "Cyber Days").
- Tiempos de respuesta superiores a 8 segundos.
- Pérdidas estimadas en S/ 15,000 por hora de inactividad.
- Imposibilidad de escalar rápido ante demanda.

### 2.2 Solución propuesta
Migrar la plataforma monolítica a una arquitectura de microservicios contenerizada y orquestada con Docker Swarm. Las ventajas:

- **Escalado horizontal:** subir réplicas en segundos sin downtime.
- **Alta disponibilidad:** si un nodo cae, Swarm reprograma sus containers en los demás.
- **Balanceo de carga automático:** routing mesh + DNS interno.
- **Gestión centralizada:** un solo manager controla todo el clúster.

---

## 3. Arquitectura implementada

### 3.1 Diagrama
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

### 3.2 Servicios

| Servicio    | Imagen                       | Réplicas | Función                        |
|-------------|------------------------------|----------|--------------------------------|
| frontend    | `nginx:alpine`               | 3        | SPA + reverse proxy al backend |
| backend     | `node:18-alpine`             | 2        | API REST mínima                |
| database    | `mysql:8`                    | 1 (mgr)  | Persistencia                   |
| cache       | `redis:7-alpine`             | 1        | Cache de consultas             |
| visualizer  | `dockersamples/visualizer`   | 1 (mgr)  | Dashboard del clúster (:8080)  |

### 3.3 Decisiones técnicas

- **Plataforma:** Play with Docker (PWD). Es gratuito, no requiere instalación local y soporta multi-nodo en segundos. Limitación: la sesión expira a las 4 horas.
- **Database anclada al manager** (`node.role == manager`): garantiza que el volumen `db_data` viva siempre en el mismo nodo. En producción real se usaría un servicio externo gestionado (ej. RDS).
- **Código del backend distribuido vía Docker Configs:** evita tener que construir y publicar una imagen propia en Docker Hub. Swarm distribuye `server.js` automáticamente a cualquier nodo donde corra una réplica.
- **Routing mesh activado:** cualquier nodo del clúster responde en el puerto 80, aunque el container del frontend no esté ahí. Swarm enruta internamente.
- **Update config con `start-first`:** permite rolling updates sin downtime — la nueva réplica arranca antes de bajar la antigua.

---

## 4. Implementación

### 4.1 Plataforma utilizada
Play with Docker (https://labs.play-with-docker.com/) con 3 instancias:

- `node1` — Manager
- `node2` — Worker
- `node3` — Worker

### 4.2 Inicialización del clúster

```bash
# En node1
docker swarm init --advertise-addr <IP_NODE1>
docker swarm join-token worker

# En node2 y node3
docker swarm join --token SWMTKN-... <IP_NODE1>:2377

# Verificación
docker node ls
```

**Captura 1:** `docker node ls` mostrando los 3 nodos.

> **[Insertar captura 01-nodes.png]**

### 4.3 Gestión de credenciales

```bash
echo "MiPasswordSegura123" | docker secret create db_password -
docker secret ls
```

El secret se monta en `/run/secrets/db_password` dentro de los containers de `backend` y `database`. Está cifrado en tránsito (TLS entre nodos) y en reposo en los managers.

> **[Insertar captura 02-secret.png]**

### 4.4 Despliegue del stack

```bash
docker stack deploy -c docker-compose.yml techretail
docker stack services techretail
```

Salida esperada:
```
ID    NAME                     MODE         REPLICAS  IMAGE
xxx   techretail_backend       replicated   2/2       node:18-alpine
xxx   techretail_cache         replicated   1/1       redis:7-alpine
xxx   techretail_database      replicated   1/1       mysql:8
xxx   techretail_frontend      replicated   3/3       nginx:alpine
xxx   techretail_visualizer    replicated   1/1       dockersamples/visualizer
```

> **[Insertar captura 03-services.png]**

### 4.5 Visualización del clúster

Acceder al visualizador en `http://<IP_MANAGER>:8080` muestra los containers distribuidos en los 3 nodos.

> **[Insertar captura 04-visualizer.png]**

### 4.6 Demo de balanceo de carga

La SPA en `http://<IP_MANAGER>/` hace `fetch('/api')` y muestra el `hostname` del container backend que respondió. Al hacer múltiples llamadas seguidas, se observa cómo Swarm distribuye las peticiones entre las 2 réplicas (round-robin).

> **[Insertar captura 05-frontend-demo.png]**

### 4.7 Escalado dinámico

```bash
docker service scale techretail_frontend=5
docker service scale techretail_backend=4
docker stack ps techretail
```

> **[Insertar captura 06-scaled.png — visualizer con réplicas escaladas]**

---

## 5. Cumplimiento de requerimientos

| # | Requerimiento                                     | Estado | Evidencia                       |
|---|---------------------------------------------------|--------|---------------------------------|
| 3.1 | Clúster con 1 manager + 2 workers               | ✅     | `docker node ls` (Captura 1)    |
| 3.2 | docker-compose con ≥4 servicios                  | ✅     | 5 servicios definidos           |
| 3.2 | Red overlay para comunicación interna           | ✅     | `techretail_net`                |
| 3.2 | Volumen para persistencia de la BD              | ✅     | `db_data:/var/lib/mysql`        |
| 3.3 | Frontend con ≥3 réplicas                         | ✅     | `replicas: 3` (escalable a 5)   |
| 3.3 | Backend con ≥2 réplicas                          | ✅     | `replicas: 2`                   |
| 3.3 | Restart policy automático                        | ✅     | `condition: on-failure`         |
| 3.3 | Demostración de escalado dinámico               | ✅     | Script `04-scale-demo.sh`       |
| 3.4 | Docker Secrets para credenciales BD             | ✅     | `db_password` (external)        |
| 3.4 | Docker Configs para archivos no sensibles       | ✅     | `nginx_conf`, `index_html`, `backend_server` |

---

## 6. Problemas encontrados y soluciones

### 6.1 [Ejemplo] El backend no arrancaba en los workers
**Causa:** La imagen base `node:18-alpine` no tenía el `server.js` porque el código vivía solo en el manager.
**Solución:** Distribuir el código mediante **Docker Configs** (`backend_server` apuntando a `./backend/server.js`). Swarm lo monta en `/app/server.js` en cualquier nodo donde corra una réplica.

### 6.2 [Completar con tu experiencia real durante la práctica]

---

## 7. Reflexión sobre Docker Swarm

### Ventajas observadas
- **Curva de aprendizaje suave:** los comandos son consistentes con los de `docker compose`.
- **Setup rápido:** un clúster de 3 nodos se levanta en menos de un minuto.
- **Routing mesh y DNS interno:** balanceo de carga automático sin configuración extra.
- **Secrets/Configs nativos:** distribución cifrada de credenciales sin servicios externos.

### Limitaciones
- **Ecosistema más pequeño** que Kubernetes (menos operadores, menos herramientas de monitoreo).
- **Sin auto-scaling nativo** basado en métricas (CPU/RAM); el escalado debe ser manual o con scripts.
- **Menos adopción en empresas grandes**, lo que afecta disponibilidad de talento.

### Cuándo usarlo
Docker Swarm es la elección correcta cuando:
- El equipo es pequeño o el tiempo de adopción debe ser corto.
- Los servicios son pocos (5-20 contenedores) y el escalado es predecible.
- No se requiere multi-cloud o features avanzadas (service mesh, custom controllers).

Para escalas mayores o requisitos avanzados, **Kubernetes** sigue siendo la opción estándar.

---

## 8. Conclusiones

1. La migración de TechRetail a Docker Swarm resolvió los problemas de disponibilidad y escalabilidad: ahora se pueden agregar réplicas en segundos sin afectar el servicio.
2. La separación del código de aplicación mediante Docker Configs simplifica el ciclo de despliegue: editar el archivo y volver a desplegar el stack basta para actualizar todas las réplicas.
3. El uso de Docker Secrets elimina el riesgo de exponer credenciales en variables de entorno o archivos `.env` versionados.
4. Para un primer paso de modernización en una empresa mediana, Docker Swarm ofrece la mejor relación valor/complejidad. Una migración futura a Kubernetes es factible si el negocio lo requiere.

---

## 9. Repositorio

Código fuente completo: `https://github.com/<TU_USUARIO>/techretail-swarm`

## 10. Video demostrativo

Enlace: `[completar tras grabar]`

---

## Anexos: Comandos utilizados

```bash
# Inicialización
docker swarm init --advertise-addr <IP>
docker swarm join-token worker

# Secret
echo "MiPasswordSegura123" | docker secret create db_password -

# Deploy
docker stack deploy -c docker-compose.yml techretail

# Verificación
docker node ls
docker stack services techretail
docker stack ps techretail
docker service logs techretail_backend

# Escalado
docker service scale techretail_frontend=5

# Limpieza
docker stack rm techretail
docker secret rm db_password
docker swarm leave --force
```
