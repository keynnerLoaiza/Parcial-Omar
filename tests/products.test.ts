import request from 'supertest';
import app from '../src/app';
import pool from '../src/db/connection';

const mockPool = pool as jest.Mocked<typeof pool>;

const sampleProducts = [
  { id: 1, name: 'Laptop', description: 'Laptop gamer', price: 1500000, created_at: new Date() },
  { id: 2, name: 'Mouse',  description: 'Mouse inalámbrico', price: 80000, created_at: new Date() },
];

describe('Products Endpoints', () => {
  // ── GET /api/products ────────────────────────────────────────
  describe('GET /api/products', () => {
    it('debe retornar lista de productos', async () => {
      (mockPool.query as jest.Mock).mockResolvedValueOnce({
        rows: sampleProducts, rowCount: 2,
      });

      const res = await request(app).get('/api/products');
      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('data');
      expect(res.body).toHaveProperty('count');
      expect(Array.isArray(res.body.data)).toBe(true);
    });

    it('debe retornar 500 si la DB falla', async () => {
      (mockPool.query as jest.Mock).mockRejectedValueOnce(new Error('DB Error'));

      const res = await request(app).get('/api/products');
      expect(res.status).toBe(500);
    });
  });

  // ── GET /api/products/:id ────────────────────────────────────
  describe('GET /api/products/:id', () => {
    it('debe retornar un producto por id', async () => {
      (mockPool.query as jest.Mock).mockResolvedValueOnce({
        rows: [sampleProducts[0]], rowCount: 1,
      });

      const res = await request(app).get('/api/products/1');
      expect(res.status).toBe(200);
      expect(res.body.data.id).toBe(1);
    });

    it('debe retornar 404 si el producto no existe', async () => {
      (mockPool.query as jest.Mock).mockResolvedValueOnce({
        rows: [], rowCount: 0,
      });

      const res = await request(app).get('/api/products/999');
      expect(res.status).toBe(404);
    });

    it('debe retornar 400 si el id no es número', async () => {
      const res = await request(app).get('/api/products/abc');
      expect(res.status).toBe(400);
    });
  });

  // ── POST /api/products ───────────────────────────────────────
  describe('POST /api/products', () => {
    it('debe crear un producto correctamente', async () => {
      const newProduct = { id: 3, name: 'Teclado', description: 'Mecánico', price: 250000 };
      (mockPool.query as jest.Mock).mockResolvedValueOnce({
        rows: [newProduct], rowCount: 1,
      });

      const res = await request(app)
        .post('/api/products')
        .send({ name: 'Teclado', description: 'Mecánico', price: 250000 });

      expect(res.status).toBe(201);
      expect(res.body.data.name).toBe('Teclado');
    });

    it('debe retornar 400 si faltan campos requeridos', async () => {
      const res = await request(app)
        .post('/api/products')
        .send({ description: 'Sin nombre ni precio' });

      expect(res.status).toBe(400);
    });
  });
});
