// =====================================================================
// 1. CARREGAR VARIÁVEIS DE AMBIENTE (DEVE SER O PRIMEIRO!)
require('dotenv').config();

// 2. IMPORTAR LIBS
const express = require('express');
const bodyParser = require('body-parser');
const path = require('path');

// 3. IMPORTAR MÓDULOS (QUE AGORA CONSEGUEM LER O .env)
const pool = require('./db');

// 🔒 Importação segura do Firebase (sem quebrar caso o arquivo não exista)
let adminFirebase = null;
try {
    adminFirebase = require('./firebase');
} catch (e) {
    console.warn('⚠️ Firebase não encontrado — notificações desativadas.');
}

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware para processar JSON nas requisições
app.use(bodyParser.json());

// ===============================================
// ROTAS VÁLIDAS DO SERVIDOR
// ===============================================

// 1️⃣ Rota Raiz (Health Check)
app.get('/', (req, res) => {
    res.status(200).json({ status: 'ok', service: 'Ticket Management API', version: '1.0', server_time: new Date() });
});

// 2️⃣ LISTAR TODOS OS USUÁRIOS
app.get('/users', async (req, res) => {
    try {
        const result = await pool.query('SELECT id, name, email, role FROM users ORDER BY name ASC');
        res.json({ users: result.rows });
    } catch (err) {
        console.error('Erro em GET /users:', err);
        res.status(500).json({ error: 'Erro ao listar usuários.' });
    }
});

// 2.1️⃣ LISTAR TÉCNICOS
app.get('/technicians', async (req, res) => {
    try {
        const result = await pool.query("SELECT id, name FROM users WHERE role = 'tech' ORDER BY name ASC");
        res.json({ technicians: result.rows });
    } catch (err) {
        console.error('Erro em GET /technicians:', err);
        res.status(500).json({ error: 'Erro ao listar técnicos.' });
    }
});

// 3️⃣ LISTAR TODOS OS TICKETS
app.get('/tickets', async (req, res) => {
    try {
        const result = await pool.query(`
            SELECT t.*, u.name AS assigned_to_name
            FROM tickets t
            LEFT JOIN users u ON t.assigned_to = u.id
            ORDER BY t.created_at DESC
        `);
        res.json({ tickets: result.rows });
    } catch (err) {
        console.error('Erro em GET /tickets:', err);
        res.status(500).json({ error: 'Erro ao listar todos os tickets.' });
    }
});

// 3.1️⃣ LISTAR TICKETS POR SOLICITANTE
app.get('/tickets/requested/:requested_by_id', async (req, res) => {
    const requestedById = req.params.requested_by_id;
    try {
        const result = await pool.query(`
            SELECT t.*, u.name AS assigned_to_name
            FROM tickets t
            LEFT JOIN users u ON t.assigned_to = u.id
            WHERE t.requested_by = $1
            ORDER BY t.created_at DESC
        `, [requestedById]);
        res.json({ tickets: result.rows });
    } catch (err) {
        console.error('Erro em GET /tickets/requested/:requested_by_id:', err);
        res.status(500).json({ error: 'Erro ao listar tickets solicitados.' });
    }
});

// 4️⃣ LOGIN
app.post('/login', async (req, res) => {
    const { email, senha } = req.body;

    if (!email || !senha) return res.status(400).json({ error: 'Email e senha são obrigatórios.' });

    try {
        const userResult = await pool.query('SELECT id, name, email, password_hash, role FROM users WHERE email = $1', [email]);
        const user = userResult.rows[0];
        if (!user || senha !== user.password_hash)
            return res.status(401).json({ error: 'Credenciais inválidas.' });

        res.json({ id: user.id, name: user.name, email: user.email, role: user.role });
    } catch (err) {
        console.error('Erro em POST /login:', err);
        res.status(500).json({ error: 'Erro interno do servidor ao tentar login.' });
    }
});

// 5️⃣ BUSCA DE CLIENTE
app.get('/clients/search', async (req, res) => {
    const { identifier } = req.query;
    if (!identifier) return res.status(400).json({ error: 'O identificador (CPF/CNPJ) é obrigatório.' });

    try {
        const result = await pool.query('SELECT id, name, address, identifier FROM customers WHERE identifier = $1', [identifier]);
        if (result.rows.length === 0) return res.status(404).json({ error: 'Cliente não encontrado.' });
        res.json(result.rows[0]);
    } catch (err) {
        console.error('Erro em GET /clients/search:', err);
        res.status(500).json({ error: 'Erro interno ao buscar cliente.' });
    }
});

// 6️⃣ CRIAR TICKET
app.post('/ticket', async (req, res) => {
    const { title, description, priority, requestedBy, clientId, customerName, address, identifier } = req.body;
    if (!title || !description || !priority || !requestedBy || !customerName || !address)
        return res.status(400).json({ error: 'Campos obrigatórios ausentes.' });

    const clientDB = await pool.connect();
    let finalClientId = clientId;

    try {
        await clientDB.query('BEGIN');
        if (!clientId) {
            if (!identifier) {
                await clientDB.query('ROLLBACK');
                return res.status(400).json({ error: 'CPF/CNPJ é obrigatório.' });
            }
            const existing = await clientDB.query('SELECT id FROM customers WHERE identifier = $1', [identifier]);
            if (existing.rows.length > 0) {
                await clientDB.query('ROLLBACK');
                return res.status(409).json({ error: `O identificador ${identifier} já está cadastrado.` });
            }
            const newClient = await clientDB.query(
                'INSERT INTO customers (name, address, identifier) VALUES ($1, $2, $3) RETURNING id',
                [customerName, address, identifier]
            );
            finalClientId = newClient.rows[0].id;
        }

        const result = await clientDB.query(`
            INSERT INTO tickets (title, description, priority, customer_id, customer_name, customer_address, requested_by, assigned_to, status)
            VALUES ($1, $2, $3, $4, $5, $6, $7, NULL, 'PENDING')
            RETURNING *
        `, [title, description, priority, finalClientId, customerName, address, requestedBy]);

        await clientDB.query('COMMIT');
        res.status(201).json({ ticket: result.rows[0] });
    } catch (err) {
        await clientDB.query('ROLLBACK');
        console.error('Erro em POST /ticket:', err);
        res.status(500).json({ error: 'Erro ao criar ticket.', details: err.message });
    } finally {
        clientDB.release();
    }
});

// 7️⃣ APROVAR TICKET
app.put('/tickets/:id/approve', async (req, res) => {
    const ticketId = req.params.id;
    const { admin_id, assigned_to } = req.body;

    const client = await pool.connect();
    try {
        await client.query('BEGIN');

        const userRes = await client.query('SELECT role FROM users WHERE id = $1', [admin_id]);
        const approver = userRes.rows[0];
        if (!approver || approver.role !== 'admin') {
            await client.query('ROLLBACK');
            return res.status(403).json({ error: 'Apenas admins podem aprovar.' });
        }

        const techCheck = await client.query('SELECT id FROM users WHERE id = $1 AND role = \'tech\'', [assigned_to]);
        if (techCheck.rows.length === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({ error: 'Técnico não encontrado.' });
        }

        const update = await client.query(`
            UPDATE tickets SET status = 'APPROVED', approved_by = $1, approved_at = now(), assigned_to = $2
            WHERE id = $3 RETURNING *
        `, [admin_id, assigned_to, ticketId]);

        const ticket = update.rows[0];
        await client.query('COMMIT');
        res.json({ ticket });
    } catch (err) {
        await client.query('ROLLBACK');
        console.error('Erro em PUT /tickets/:id/approve:', err);
        res.status(500).json({ error: 'Erro ao aprovar ticket.' });
    } finally {
        client.release();
    }
});

// 8️⃣ REJEITAR TICKET
app.put('/tickets/:id/reject', async (req, res) => {
    const ticketId = req.params.id;
    const { admin_id } = req.body;
    try {
        const result = await pool.query(`
            UPDATE tickets SET status = 'REJECTED', approved_by = $1, approved_at = now(), assigned_to = NULL
            WHERE id = $2 RETURNING *
        `, [admin_id, ticketId]);
        if (result.rows.length === 0) return res.status(404).json({ error: 'Ticket não encontrado.' });
        res.json({ message: 'Ticket rejeitado.', ticket: result.rows[0] });
    } catch (err) {
        console.error('Erro em PUT /tickets/:id/reject:', err);
        res.status(500).json({ error: 'Erro ao rejeitar ticket.' });
    }
});

// 9️⃣ LISTAR TICKETS DE UM TÉCNICO
app.get('/tickets/assigned/:tech_id', async (req, res) => {
    const techId = req.params.tech_id;
    try {
        const result = await pool.query(`
            SELECT t.*, u.name AS approved_by_admin_name
            FROM tickets t
            LEFT JOIN users u ON t.approved_by = u.id
            WHERE t.status = 'APPROVED' AND t.assigned_to = $1
            ORDER BY t.created_at DESC
        `, [techId]);
        res.json({ tickets: result.rows });
    } catch (err) {
        console.error('Erro em GET /tickets/assigned/:tech_id:', err);
        res.status(500).json({ error: 'Erro ao listar tickets.' });
    }
});

// 🆕 🔟 ATUALIZAR STATUS DO TICKET (para técnico encerrar ou mudar estado)
console.log('🔧 Registrando rota: PUT /tickets/:id/status');
app.put('/tickets/:id/status', async (req, res) => {
    const ticketId = req.params.id;
    const { status } = req.body;

    if (!status) return res.status(400).json({ error: 'Status é obrigatório.' });

    try {
        const result = await pool.query(
            `UPDATE tickets SET status = $1, updated_at = now() WHERE id = $2 RETURNING *`,
            [status, ticketId]
        );

        if (result.rows.length === 0)
            return res.status(404).json({ error: 'Ticket não encontrado.' });

        res.json({ message: 'Status atualizado com sucesso.', ticket: result.rows[0] });
    } catch (err) {
        console.error('Erro em PUT /tickets/:id/status:', err);
        res.status(500).json({ error: 'Erro ao atualizar status.', details: err.message });
    }
});

// ===============================================
// MIDDLEWARES DE ERRO
// ===============================================
app.use((req, res) => {
    res.status(404).json({
        error: "Rota não encontrada",
        message: `O recurso ${req.originalUrl} usando o método ${req.method} não existe ou a URL está incorreta.`
    });
});

app.use((err, req, res, next) => {
    console.error('Tratador de Erro Geral (500):', err.stack);
    res.status(500).json({
        error: 'Erro interno inesperado no servidor.',
        message: err.message,
        path: req.originalUrl
    });
});

// ===============================================
// INICIALIZAÇÃO DO SERVIDOR
// ===============================================
app.listen(PORT, () => {
    console.log(`Servidor Express rodando na porta ${PORT}`);
    console.log(`Base URL: ${process.env.RENDER_EXTERNAL_URL || `http://localhost:${PORT}`}`);
});
