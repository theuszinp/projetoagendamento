// =====================================================================
// 🌐 CONFIGURAÇÃO GERAL DO SERVIDOR (Refatorado para Rotas Modulares)
// =====================================================================

// 1. CARREGAR VARIÁVEIS DE AMBIENTE (DEVE SER O PRIMEIRO!)
require('dotenv').config();

// 2. IMPORTAR LIBS
const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const morgan = require('morgan');
const jwt = require('jsonwebtoken');
const pool = require('./db'); // conexão com PostgreSQL
// O restante das libs (bcrypt, path) será importado apenas nos arquivos de rota onde é necessário

// Checa se o arquivo firebase.js existe antes de tentar importar
const adminFirebase = require.resolve('./firebase') ? require('./firebase') : null;

// 3. CONFIGURAR EXPRESS
const app = express();
const PORT = process.env.PORT || 10000; 

// 4. MIDDLEWARES GLOBAIS
app.use(cors({ origin: '*' }));
app.use(bodyParser.json());
app.use(morgan('combined'));

// 5. JWT Middleware (Middleware de Aplicação, fica no server.js)
function authMiddleware(req, res, next) {
    const header = req.headers['authorization'];
    if (!header) return res.status(401).json({ success: false, message: 'Token ausente.' });

    const token = header.split(' ')[1];
    if (!token) return res.status(401).json({ success: false, message: 'Formato do Token inválido.' });

    try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        req.user = decoded; // { id, role } -> req.user.id é um number se for integer no JWT payload
        next();
    } catch (err) {
        return res.status(403).json({ success: false, message: 'Token inválido ou expirado.' });
    }
}
// Exporta para que os módulos de rota possam usá-lo
exports.authMiddleware = authMiddleware;

// 6. Middleware de Autorização por Role (Exporta para ser usado nas rotas)
function roleMiddleware(requiredRole) {
    return (req, res, next) => {
        if (req.user.role !== requiredRole) {
            return res.status(403).json({ success: false, message: `Acesso negado. Requer role: ${requiredRole}` });
        }
        next();
    };
}
exports.roleMiddleware = roleMiddleware;


// =====================================================================
// 7. CARREGAMENTO DAS ROTAS MODULARES (NOVO!)
// =====================================================================
const authRoutes = require('./routes/auth');
const userRoutes = require('./routes/users');
const clientRoutes = require('./routes/clients');
const ticketRoutes = require('./routes/tickets');

// Monta os módulos de rota
app.use('/', authRoutes);      // /login, /users (criação)
app.use('/users', userRoutes); // Rotas de usuários protegidas
app.use('/clients', clientRoutes); // Rotas de clientes protegidas
app.use('/tickets', ticketRoutes); // Rotas de tickets protegidas

// ROTA TESTE PÚBLICA (Health Check)
app.get('/', (req, res) => {
    res.json({
        success: true,
        message: 'API TrackerCars - Online 🚗',
        version: '3.0-refatorada-final', // Versão atualizada
    });
});


// =====================================================================
// 🧱 CRIAÇÃO DE ÍNDICES AUTOMÁTICA (executa uma vez no start)
// =====================================================================
// **MANTENHA ESTA SEÇÃO AQUI, POIS ELA PRECISA DO 'pool' E RODA AO INICIAR**
(async () => {
    try {
        await pool.query(`
            DO $$ 
            BEGIN
                -- Adiciona a coluna tech_status se ela ainda não existir
                IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='tickets' AND column_name='tech_status') THEN
                    ALTER TABLE tickets ADD COLUMN tech_status VARCHAR(50) DEFAULT NULL;
                END IF;
            END 
            $$;
        `);
        // Adicionamos índices para as colunas mais usadas em WHERE/JOIN
        await pool.query(`CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);`);
        await pool.query(`CREATE INDEX IF NOT EXISTS idx_tickets_assigned_to ON tickets(assigned_to);`);
        await pool.query(`CREATE INDEX IF NOT EXISTS idx_tickets_requested_by ON tickets(requested_by);`);
        await pool.query(`CREATE INDEX IF NOT EXISTS idx_customers_identifier ON customers(identifier);`);
        await pool.query(`CREATE INDEX IF NOT EXISTS idx_tickets_tech_status ON tickets(tech_status);`);

        console.log('🔍 Índices do banco verificados/criados.');
    } catch (err) {
        console.error('Erro ao criar índices/colunas:', err);
    }
})();


// =====================================================================
// ⚙️ TRATAMENTO DE ERROS GLOBAIS
// =====================================================================

// 🚨 TRATAMENTO DE ROTA NÃO ENCONTRADA (404)
app.use((req, res) => {
    res.status(404).json({ success: false, message: 'Rota não encontrada.', path: req.originalUrl });
});

// 🚨 MIDDLEWARE DE TRATAMENTO DE ERRO CENTRALIZADO (500)
app.use((err, req, res, next) => {
    console.error('Erro interno:', err.stack);
    const statusCode = err.statusCode || 500;
    res.status(statusCode).json({
        success: false,
        message: 'Erro interno no servidor.',
        details: err.message,
        path: req.originalUrl
    });
});

// =====================================================================
// 🧩 INICIAR SERVIDOR
// =====================================================================
app.listen(PORT, () => {
    console.log(`✅ Servidor rodando na porta ${PORT}`);
    const baseUrl = process.env.RENDER_EXTERNAL_URL || `http://localhost:${PORT}`;
    console.log(`Base URL: ${baseUrl}`);
});