import { Router, Request, Response } from 'express';
import pool from '../db/connection';

const router = Router();

// ── GET /health ──────────────────────────────────────────────
// Endpoint liviano para el health-check del balanceador (ALB)
router.get('/health', (_req: Request, res: Response) => {
  res.status(200).json({
    status:    'ok',
    timestamp: new Date().toISOString(),
    service:   'aws-api-rest',
    version:   process.env.APP_VERSION || '1.0.0',
  });
});

// ── GET /status ──────────────────────────────────────────────
// Estado completo: app + conectividad con la base de datos
router.get('/status', async (_req: Request, res: Response) => {
  try {
    const start = Date.now();
    await pool.query('SELECT 1');
    const dbLatencyMs = Date.now() - start;

    res.status(200).json({
      status:      'ok',
      database:    'connected',
      dbLatencyMs,
      uptimeSeconds: Math.floor(process.uptime()),
      memoryMB: {
        rss:      (process.memoryUsage().rss      / 1_048_576).toFixed(1),
        heapUsed: (process.memoryUsage().heapUsed / 1_048_576).toFixed(1),
      },
      nodeVersion: process.version,
    });
  } catch (err) {
    res.status(503).json({
      status:   'degraded',
      database: 'disconnected',
      error:    (err as Error).message,
    });
  }
});

// ── GET /api/test ─────────────────────────────────────────────
router.get('/api/test', (_req: Request, res: Response) => {
  res.status(200).json({
    message: 'API funcionando correctamente',
    env:     process.env.NODE_ENV || 'development',
  });
});

export default router;
