import http from 'k6/http';
import { check, sleep } from 'k6';

// ==============================================================================
// Configuración de la Prueba de Carga (Rampa de Usuarios Virtuales)
// ==============================================================================
export const options = {
  stages: [
    { duration: '30s', target: 20 }, // Rampa ascendente: de 0 a 20 usuarios en 30s
    { duration: '1m',  target: 50 }, // Pico de carga: de 20 a 50 usuarios en 1m
    { duration: '1m',  target: 50 }, // Sostener carga: mantener 50 usuarios por 1m
    { duration: '30s', target: 0  }, // Rampa descendente: de 50 a 0 usuarios en 30s
  ],
  thresholds: {
    http_req_failed: ['rate<0.01'],   // El porcentaje de errores debe ser menor al 1%
    http_req_duration: ['p(95)<500'], // El 95% de las peticiones debe tardar menos de 500ms
  },
};

// Obtener la URL objetivo de las variables de entorno o usar localhost por defecto
const BASE_URL = __ENV.TARGET_URL || 'http://localhost:8080';

// ==============================================================================
// Escenario de Prueba (Flujo de Usuario Simulado)
// ==============================================================================
export default function () {
  // Configuración de headers estándar
  const params = {
    headers: {
      'Content-Type': 'application/json',
    },
  };

  // ── 1. Validar endpoint liviano (/health) ───────────────────
  let res = http.get(`${BASE_URL}/health`, params);
  check(res, {
    'health responde 200': (r) => r.status === 200,
    'health status es ok': (r) => r.json().status === 'ok',
  });
  sleep(1);

  // ── 2. Validar endpoint de prueba (/api/test) ───────────────
  res = http.get(`${BASE_URL}/api/test`, params);
  check(res, {
    'api/test responde 200': (r) => r.status === 200,
  });
  sleep(1);

  // ── 3. Listar productos (/api/products) ─────────────────────
  res = http.get(`${BASE_URL}/products`, params); // Nota: Express mapea app.use('/api', productsRouter), por lo que es /api/products
  // Espera, en app.ts: app.use('/api', productsRouter); y en products.ts: router.get('/products', ...)
  // Por lo tanto, el endpoint final es /api/products !
  res = http.get(`${BASE_URL}/api/products`, params);
  check(res, {
    'GET /api/products responde 200': (r) => r.status === 200,
    'retorna lista de datos': (r) => Array.isArray(r.json().data),
  });
  sleep(1.5);

  // ── 4. Simular Creación de un Producto (POST /api/products) ──
  const payload = JSON.stringify({
    name: `Producto k6-${__VU}-${__ITER}`,
    description: 'Producto de prueba generado automáticamente por la prueba de carga k6',
    price: Math.floor(Math.random() * 1000) + 10,
  });

  res = http.post(`${BASE_URL}/api/products`, payload, params);
  check(res, {
    'POST /api/products responde 201': (r) => r.status === 201,
    'retorna producto creado con id': (r) => r.json().data.id !== undefined,
  });

  const createdId = res.status === 201 ? res.json().data.id : null;
  sleep(1.5);

  // ── 5. Consultar el producto específico creado (GET /api/products/:id) ──
  if (createdId) {
    res = http.get(`${BASE_URL}/api/products/${createdId}`, params);
    check(res, {
      'GET /api/products/:id responde 200': (r) => r.status === 200,
      'el nombre coincide': (r) => r.json().data.name.startsWith('Producto k6-'),
    });
    sleep(1);

    // ── 6. Limpieza: Eliminar el producto creado (DELETE /api/products/:id) ──
    res = http.del(`${BASE_URL}/api/products/${createdId}`, null, params);
    check(res, {
      'DELETE /api/products/:id responde 200': (r) => r.status === 200,
    });
    sleep(1);
  }

  // ── 7. Consultar estado del sistema y la base de datos (/status) ──
  // Nota: Este endpoint realiza una consulta real "SELECT 1" a la base de datos
  res = http.get(`${BASE_URL}/status`, params);
  check(res, {
    'status responde 200': (r) => r.status === 200,
    'db esta conectada': (r) => r.json().database === 'connected',
  });
  sleep(2);
}
