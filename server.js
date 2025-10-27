// =====================================================================
// 🌐 CONFIGURAÇÃO GERAL DO SERVIDOR (Refatorado para Rotas Modulares)
// =====================================================================

// 1️⃣ CARREGAR VARIÁVEIS DE AMBIENTE (DEVE SER O PRIMEIRO!)
require('dotenv').config();

// 2️⃣ IMPORTAR LIBS
const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const morgan = require('morgan');
const jwt = require('jsonwebtoken');
const pool = require('./db'); // Conexão com PostgreSQL
const fs = require('fs'); // Usado para checar firebase.js

// ✅ Checa se o arquivo firebase.js existe antes de importar
let adminFirebase = null;
if (fs.existsSync('./firebase.js')) {
    adminFirebase = require('./firebase');
}

// 3️⃣ CONFIGURAR EXPRESS
const app = express();
const PORT = process.env.PORT || 10000;

// 4️⃣ MIDDLEWARES GLOBAIS
app.use(cors({ origin: '*' }));
app.use(bodyParser.json());
app.use(morgan('combined'));

// =====================================================================
// 🔐 MIDDLEWARES DE AUTENTICAÇÃO E AUTORIZAÇÃO
// =====================================================================

// JWT Auth Middleware
function authMiddleware(req, res, next) {
    const header = req.headers['authorization'];
    if (!header) {
        return res.status(401).json({ success: false, message: 'Token ausente.' });
    }

    const parts = header.split(' ');
    if (parts.length !== 2 || parts[0] !== 'Bearer') {
        return res.status(401).json({ success: false, message: 'Formato do token inválido.' });
    }

    const token = parts[1];
    try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        req.user = decoded; // Ex: { id, role }
        next();
    } catch (err) {
        return res.status(403).json({ success: false, message: 'Token inválido ou expirado.' });
    }
}
exports.authMiddleware = authMiddleware;

// Role Middleware
function roleMiddleware(requiredRole) {
    return (req, res, next) => {
        if (!req.user || req.user.role !== requiredRole) {
            return res.status(403).json({ success: false, message: `Acesso negado. Requer role: ${requiredRole}` });
        }
        next();
    };
}
exports.roleMiddleware = roleMiddleware;

// =====================================================================
// 🧩 ROTAS MODULARES
// =====================================================================
const authRoutes = require('./routes/auth');
const userRoutes = require('./routes/users');
const clientRoutes = require('./routes/clients');
const ticketRoutes = require('./routes/tickets');

app.use('/', authRoutes);          // /login, /users (criação)
app.use('/users', userRoutes);     // Rotas protegidas de usuários
app.use('/clients', clientRoutes); // Rotas protegidas de clientes
app.use('/tickets', ticketRoutes); // Rotas protegidas de tickets

// Health check (rota pública)
app.get('/', (req, res) => {
    res.json({
        success: true,
        message: 'API TrackerCars - Online 🚗',
        version: '3.0-refatorada-final',
    });
});

// =====================================================================
// 🧱 CRIAÇÃO DE ÍNDICES AUTOMÁTICA
// =====================================================================
(async () => {
    try {
        await pool.query(`
            DO $$
            BEGIN
                IF NOT EXISTS (
                    SELECT 1 FROM information_schema.columns 
                    WHERE table_name='tickets' AND column_name='tech_status'
                ) THEN
                    ALTER TABLE tickets ADD COLUMN tech_status VARCHAR(50) DEFAULT NULL;
                END IF;
            END
            $$;
        `);

        const indexes = [
            `CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);`,
            `CREATE INDEX IF NOT EXISTS idx_tickets_assigned_to ON tickets(assigned_to);`,
            `CREATE INDEX IF NOT EXISTS idx_tickets_requested_by ON tickets(requested_by);`,
            `CREATE INDEX IF NOT EXISTS idx_customers_identifier ON customers(identifier);`,
            `CREATE INDEX IF NOT EXISTS idx_tickets_tech_status ON tickets(tech_status);`
        ];

        for (const query of indexes) {
            await pool.query(query);
        }

        console.log('🔍 Índices e colunas verificados/criados com sucesso.');
    } catch (err) {
        console.error('❌ Erro ao criar índices/colunas:', err);
    }
})();

// =====================================================================
// ⚙️ TRATAMENTO DE ERROS GLOBAIS
// =====================================================================

// 404 - Rota não encontrada
app.use((req, res) => {
    res.status(404).json({ success: false, message: 'Rota não encontrada.', path: req.originalUrl });
});

// 500 - Erros internos
app.use((err, req, res, next) => {
    console.error('Erro interno:', err.stack);
    res.status(err.statusCode || 500).json({
        success: false,
        message: 'Erro interno no servidor.',
        details: err.message,
        path: req.originalUrl
    });
});

// =====================================================================
// 🚀 INICIAR SERVIDOR
// =====================================================================
app.listen(PORT, () => {
    console.log(`✅ Servidor rodando na porta ${PORT}`);
    const baseUrl = process.env.RENDER_EXTERNAL_URL || `http://localhost:${PORT}`;
    console.log(`🌐 Base URL: ${baseUrl}`);
});
