// Mock del pool de PostgreSQL para que los tests corran sin DB real
const pool = {
  query: jest.fn(),
  on: jest.fn(),
};

export default pool;
