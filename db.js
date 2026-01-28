// db.js - Configuração de Conexão com o PostgreSQL
const { Pool } = require('pg');
require('dotenv').config();

// Garante que a variável de ambiente está carregada
const connectionString = process.env.DATABASE_URL;

if (!connectionString) {
    console.error("ERRO CRÍTICO: Variável de ambiente DATABASE_URL não definida!");
    // Interrompe o processo se a variável não estiver lá
    process.exit(1); 
}

// ----------------------------------------------------
// Configuração do SSL: 
// Aplica a configuração SSL necessária para provedores como Render/Heroku,
// que geralmente requerem 'rejectUnauthorized: false'.
// A condição verifica se estamos em um ambiente de produção que usa SSL.
// ----------------------------------------------------
const sslConfig = connectionString.includes('ssl=true') || connectionString.includes('amazonaws.com') 
    ? { rejectUnauthorized: false }
    : false; // 'false' desativa o SSL se não for detectado (bom para ambiente local)


const pool = new Pool({
    connectionString: connectionString,
    
    // Configuração SSL dinâmica
    ssl: sslConfig, 
    
    // === Configurações de Resiliência para Timeouts Ociosos ===
    // 1. idleTimeoutMillis: Tempo máximo que um cliente pode ficar ocioso no pool antes de ser removido.
    // Usamos um valor alto (30s) para evitar que o Node.js feche antes do DB,
    // mas ainda permite a reciclagem de conexões.
    idleTimeoutMillis: 30000, 
    
    // 2. connectionTimeoutMillis: Tempo máximo para o cliente tentar se conectar.
    connectionTimeoutMillis: 10000, // 10 segundos
    
    // 3. max: Define o número máximo de clientes que o pool pode ter.
    // Definir como 20 é um padrão razoável para a maioria dos planos gratuitos/iniciais.
    max: 20, 
});

// --- TRATAMENTO DE ERRO CRÍTICO ---
// Este evento escuta erros em clientes ociosos (por exemplo, se o provedor 
// de DB fechar uma conexão por inatividade). O Pool gerencia a remoção e
// criação de um novo cliente na próxima requisição.
pool.on('error', (err, client) => {
    console.error('Erro inesperado em um cliente inativo do pool do PostgreSQL', err.stack);
});


// --- TESTE DE CONEXÃO E INICIALIZAÇÃO ---
// Testa a conexão ao iniciar para garantir que o serviço de DB está acessível
pool.connect()
    .then(client => {
        // Se a conexão for bem-sucedida, loga e libera o cliente
        console.log('Pool do PostgreSQL conectado e testado com sucesso!');
        client.release(); 
    })
    .catch(err => {
        console.error('ERRO CRÍTICO: Falha ao conectar/testar o Pool do PostgreSQL:', err.stack);
        // Não encerra o processo aqui, pois o Pool pode se recuperar,
        // mas é um aviso importante para o log.
    });


module.exports = pool;
