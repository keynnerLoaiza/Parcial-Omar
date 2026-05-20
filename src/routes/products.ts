import { Router, Request, Response } from 'express';
import pool from '../db/connection';

const router = Router();

// ── GET /api/products ─────────────────────────────────────────
router.get('/products', async (_req: Request, res: Response) => {
  try {
    const result = await pool.query(
      'SELECT * FROM products ORDER BY created_at DESC LIMIT 100'
    );
    res.status(200).json({ data: result.rows, count: result.rowCount });
  } catch (err) {
    res.status(500).json({ error: (err as Error).message });
  }
});

// ── GET /api/products/:id ─────────────────────────────────────
router.get('/products/:id', async (req: Request, res: Response) => {
  const { id } = req.params;
  if (isNaN(Number(id))) {
    return res.status(400).json({ error: 'id debe ser un número' });
  }
  try {
    const result = await pool.query(
      'SELECT * FROM products WHERE id = $1', [id]
    );
    if (!result.rowCount) {
      return res.status(404).json({ error: 'Producto no encontrado' });
    }
    res.status(200).json({ data: result.rows[0] });
  } catch (err) {
    res.status(500).json({ error: (err as Error).message });
  }
});

// ── POST /api/products ────────────────────────────────────────
router.post('/products', async (req: Request, res: Response) => {
  const { name, description, price } = req.body as {
    name?: string; description?: string; price?: number;
  };

  if (!name || price === undefined) {
    return res.status(400).json({ error: 'name y price son requeridos' });
  }

  try {
    const result = await pool.query(
      `INSERT INTO products (name, description, price)
       VALUES ($1, $2, $3) RETURNING *`,
      [name, description ?? null, price]
    );
    res.status(201).json({ data: result.rows[0] });
  } catch (err) {
    res.status(500).json({ error: (err as Error).message });
  }
});

// ── DELETE /api/products/:id ──────────────────────────────────
router.delete('/products/:id', async (req: Request, res: Response) => {
  const { id } = req.params;
  try {
    const result = await pool.query(
      'DELETE FROM products WHERE id = $1 RETURNING id', [id]
    );
    if (!result.rowCount) {
      return res.status(404).json({ error: 'Producto no encontrado' });
    }
    res.status(200).json({ message: `Producto ${id} eliminado` });
  } catch (err) {
    res.status(500).json({ error: (err as Error).message });
  }
});

export default router;
