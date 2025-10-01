// db.js
const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  // A URL de conexão é lida da variável DATABASE_URL no .env
  connectionString: process.env.DATABASE_URL,
});

// Opcional: Testa a conexão ao iniciar
pool.connect((err) => {
  if (err) {
    console.error('Erro ao conectar ao PostgreSQL:', err.stack);
  } else {
    console.log('Conectado ao PostgreSQL com sucesso!');
  }
});

module.exports = pool;