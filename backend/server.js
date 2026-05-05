// ============================================================================
// TechRetail - Backend API (Node.js, sin dependencias)
// ----------------------------------------------------------------------------
// Servidor HTTP minimo que expone informacion del container que responde.
// Util para demostrar el load-balancing automatico de Docker Swarm:
// cada peticion puede ser respondida por una replica distinta.
// ============================================================================

const http = require('http');
const os = require('os');
const fs = require('fs');

const PORT = 3000;
let requestCount = 0;
const startedAt = new Date();

// Lee el secret montado por Swarm (no lo expone, solo verifica que existe)
function checkDbSecret() {
  try {
    const pwd = fs.readFileSync('/run/secrets/db_password', 'utf8').trim();
    return pwd.length > 0 ? 'loaded' : 'empty';
  } catch (e) {
    return 'missing';
  }
}

const server = http.createServer((req, res) => {
  requestCount++;

  const payload = {
    service: 'TechRetail Backend',
    container_hostname: os.hostname(),
    node_platform: `${os.platform()} ${os.arch()}`,
    cpus: os.cpus().length,
    memory_mb: Math.round(os.totalmem() / 1024 / 1024),
    uptime_seconds: Math.floor(process.uptime()),
    started_at: startedAt.toISOString(),
    request_count: requestCount,
    db_secret_status: checkDbSecret(),
    env: {
      NODE_ENV: process.env.NODE_ENV || 'unset',
      DB_HOST: process.env.DB_HOST || 'unset',
      REDIS_HOST: process.env.REDIS_HOST || 'unset',
    },
    timestamp: new Date().toISOString(),
  };

  res.writeHead(200, {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Origin': '*',
    'X-Container-Hostname': os.hostname(),
  });
  res.end(JSON.stringify(payload, null, 2));
});

server.listen(PORT, () => {
  console.log(`[${os.hostname()}] TechRetail backend escuchando en puerto ${PORT}`);
  console.log(`[${os.hostname()}] DB secret: ${checkDbSecret()}`);
});

// Manejo limpio de senales (Swarm envia SIGTERM al hacer scale down)
process.on('SIGTERM', () => {
  console.log(`[${os.hostname()}] SIGTERM recibido, cerrando...`);
  server.close(() => process.exit(0));
});
