import request from 'supertest';
import app from '../src/app';
import pool from '../src/db/connection';

const mockPool = pool as jest.Mocked<typeof pool>;

describe('Health Endpoints', () => {
  // ── GET /health ─────────────────────────────────────────────
  describe('GET /health', () => {
    it('debe retornar 200 con status ok', async () => {
      const res = await request(app).get('/health');
      expect(res.status).toBe(200);
      expect(res.body.status).toBe('ok');
      expect(res.body).toHaveProperty('timestamp');
      expect(res.body).toHaveProperty('service');
      expect(res.body).toHaveProperty('version');
    });
  });

  // ── GET /status ─────────────────────────────────────────────
  describe('GET /status', () => {
    it('debe retornar 200 cuando la DB responde', async () => {
      (mockPool.query as jest.Mock).mockResolvedValueOnce({ rows: [{ '?column?': 1 }] });

      const res = await request(app).get('/status');
      expect(res.status).toBe(200);
      expect(res.body.status).toBe('ok');
      expect(res.body.database).toBe('connected');
      expect(res.body).toHaveProperty('dbLatencyMs');
      expect(res.body).toHaveProperty('uptimeSeconds');
    });

    it('debe retornar 503 cuando la DB falla', async () => {
      (mockPool.query as jest.Mock).mockRejectedValueOnce(new Error('Connection refused'));

      const res = await request(app).get('/status');
      expect(res.status).toBe(503);
      expect(res.body.status).toBe('degraded');
      expect(res.body.database).toBe('disconnected');
    });
  });

  // ── GET /api/test ────────────────────────────────────────────
  describe('GET /api/test', () => {
    it('debe retornar 200 con mensaje de confirmación', async () => {
      const res = await request(app).get('/api/test');
      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('message');
    });
  });

  // ── Ruta inexistente ─────────────────────────────────────────
  describe('Ruta no existente', () => {
    it('debe retornar 404', async () => {
      const res = await request(app).get('/ruta-que-no-existe');
      expect(res.status).toBe(404);
    });
  });
});
