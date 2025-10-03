// db.js
const { Pool } = require('pg');
require('dotenv').config();

// Garante que a variável de ambiente está carregada
const connectionString = process.env.DATABASE_URL;

if (!connectionString) {
    console.error("ERRO CRÍTICO: Variável de ambiente DATABASE_URL não definida!");
    // Interrompe o processo se a variável não estiver lá
    process.exit(1); 
}

const pool = new Pool({
    connectionString: connectionString,
    // Configuração SSL para ambientes como Render (se for o caso)
    ssl: {
        rejectUnauthorized: false
    },
    // === Configurações de Resiliência para Timeouts Ociosos ===
    
    // 1. idleTimeoutMillis: Define o tempo máximo que um cliente pode ficar ocioso no pool antes de ser removido.
    //    Definir como 0 evita que o Pool do Node.js remova a conexão,
    //    mas o provedor (Render/PostgreSQL) ainda pode fechar por inatividade.
    //    Vamos usar um valor alto para dar mais chance: 30 segundos
    idleTimeoutMillis: 30000, 
    
    // 2. connectionTimeoutMillis: Tempo máximo para o cliente tentar se conectar.
    connectionTimeoutMillis: 10000, // 10 segundos
});

// --- TRATAMENTO DE ERRO CRÍTICO ---
// Este evento é o que evita que o seu servidor caia.
// Ele escuta erros em qualquer cliente ocioso que o provedor de DB tenha encerrado.
pool.on('error', (err, client) => {
    // O pool vai automaticamente descartar o cliente com erro e tentar
    // criar um novo na próxima requisição. Apenas logamos o erro.
    console.error('Erro inesperado em um cliente inativo do pool do PostgreSQL', err.stack);
});


// Opcional: Testa a conexão ao iniciar (usando o Pool)
pool.connect((err, client, done) => {
    // É importante chamar 'done()' para liberar o cliente de volta para o pool
    done(); 
    if (err) {
        console.error('Erro ao conectar ao PostgreSQL:', err.stack);
        // Não encerramos o processo aqui, pois o Pool pode se recuperar
    } else {
        console.log('Pool do PostgreSQL conectado com sucesso!');
    }
});


module.exports = pool;