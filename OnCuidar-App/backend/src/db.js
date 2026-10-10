// Pool de conexiones a PostgreSQL
const { Pool } = require('pg');
const config = require('./config');

const pool = new Pool({ connectionString: config.databaseUrl });

// Ejecuta fn(cliente) dentro de una transaccion; confirma al terminar o revierte si falla
async function transaccion(fn) {
  const cliente = await pool.connect();
  try {
    await cliente.query('BEGIN');
    const resultado = await fn(cliente);
    await cliente.query('COMMIT');
    return resultado;
  } catch (e) {
    await cliente.query('ROLLBACK');
    throw e;
  } finally {
    cliente.release();
  }
}

module.exports = {
  pool,
  consulta: (texto, params) => pool.query(texto, params),
  transaccion,
};
