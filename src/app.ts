import express, { Request, Response, NextFunction } from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import healthRouter   from './routes/health';
import productsRouter from './routes/products';
import pool from './db/connection';

dotenv.config();

const app  = express();
const PORT = parseInt(process.env.PORT || '8080');

// ── Middlewares ───────────────────────────────────────────────
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Log básico de cada request
app.use((req: Request, _res: Response, next: NextFunction) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
  next();
});

// ── Rutas ─────────────────────────────────────────────────────
app.use('/',    healthRouter);
app.use('/api', productsRouter);

// ── 404 ───────────────────────────────────────────────────────
app.use((_req: Request, res: Response) => {
  res.status(404).json({ error: 'Ruta no encontrada' });
});

// ── Error handler global ──────────────────────────────────────
// eslint-disable-next-line @typescript-eslint/no-unused-vars
app.use((err: Error, _req: Request, res: Response, _next: NextFunction) => {
  console.error('[ERROR]', err.message);
  res.status(500).json({ error: 'Internal server error' });
});

// ── Inicialización de la Base de Datos ─────────────────────────
async function initializeDatabase() {
  if (process.env.NODE_ENV === 'test') {
    // Evitar inicialización real durante la ejecución de pruebas unitarias
    return;
  }
  try {
    console.log('[DB] Verificando conexión e inicializando base de datos...');
    
    // Crear tabla si no existe
    await pool.query(`
      CREATE TABLE IF NOT EXISTS products (
        id SERIAL PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        description TEXT,
        price NUMERIC(10, 2) NOT NULL,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );
    `);
    console.log('[DB] Tabla "products" verificada/creada.');

    // Verificar si hay registros
    const result = await pool.query('SELECT COUNT(*) FROM products');
    const count = parseInt(result.rows[0].count);

    if (count === 0) {
      console.log('[DB] Insertando productos semilla...');
      await pool.query(`
        INSERT INTO products (name, description, price) VALUES
        ('Laptop Gamer Pro', 'Procesador Intel i9, 32GB RAM, 1TB SSD, RTX 4080', 2499.99),
        ('Monitor Curvo 34"', 'UltraWide Quad HD, 144Hz, HDR 400', 449.50),
        ('Teclado Mecánico RGB', 'Switches Cherry MX Red, layout español', 129.99),
        ('Mouse Gamer Inalámbrico', 'Sensor óptico 26K DPI, ultraliviano 63g', 79.99),
        ('Auriculares Hi-Fi con ANC', 'Cancelación activa de ruido, autonomía 40h', 199.00);
      `);
      console.log('[DB] Productos semilla insertados con éxito.');
    }
  } catch (error) {
    console.error('[DB] Error al inicializar la base de datos:', (error as Error).message);
  }
}

// ── Start ─────────────────────────────────────────────────────
if (require.main === module) {
  app.listen(PORT, async () => {
    console.log(`Servidor iniciado en puerto ${PORT} | env=${process.env.NODE_ENV || 'development'}`);
    await initializeDatabase();
  });
}

export default app;
