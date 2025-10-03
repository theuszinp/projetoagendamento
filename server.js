// server.js (VERSÃO FINAL COM TODAS AS ROTAS)
// =====================================================================

// 🚨 1. CARREGAR VARIÁVEIS DE AMBIENTE (DEVE SER O PRIMEIRO!)
require('dotenv').config(); 

// 2. IMPORTAR LIBS
const express = require('express');
const bodyParser = require('body-parser');

// 3. IMPORTAR MÓDULOS (QUE AGORA CONSEGUEM LER O .env)
const pool = require('./db');
const adminFirebase = require('./firebase'); 

const app = express();
// Se estiver rodando localmente, use 3000. No Render, ele usará a variável PORT.
const PORT = process.env.PORT || 3000; 

// Middleware para processar JSON nas requisições
app.use(bodyParser.json());

// ===============================================
// 1️⃣ Rota Raiz (Health Check)
// ===============================================
app.get('/', (req, res) => {
    // Rota simples para verificar se o servidor está ativo
    res.status(200).json({ status: 'ok', service: 'Ticket Management API', version: '1.0' });
});

// ===============================================
// 4️⃣ Rota: Login de Usuário
// ===============================================
app.post('/login', async (req, res) => {
    const { email, senha } = req.body;

    if (!email || !senha) {
        return res.status(400).json({ error: 'Email e senha são obrigatórios.' });
    }

    try {
        const userResult = await pool.query(
            'SELECT id, name, email, password_hash, role FROM users WHERE email = $1', 
            [email]
        );
        const user = userResult.rows[0];

        if (!user) {
            return res.status(401).json({ error: 'Credenciais inválidas.' });
        }

        // !!! PONTO CRÍTICO: Configurado para teste de texto puro. !!!
        // Se usar bcrypt/hash, mude para: const isMatch = await bcrypt.compare(senha, user.password_hash);
        const isMatch = senha === user.password_hash; 
        
        if (!isMatch) {
            return res.status(401).json({ error: 'Credenciais inválidas.' });
        }

        // Retorna os dados do usuário
        res.json({
            id: user.id,
            name: user.name,
            email: user.email,
            role: user.role
        });

    } catch (err) {
        console.error('Erro em POST /login:', err);
        res.status(500).json({ error: 'Erro interno do servidor ao tentar login.', details: err.message });
    }
});

// ===============================================
// 5️⃣ Rota: BUSCA DE CLIENTE 
// ===============================================
app.get('/clients/search', async (req, res) => {
    const { identifier } = req.query; 

    if (!identifier) {
        return res.status(400).json({ error: 'O identificador (CPF/CNPJ) do cliente é obrigatório.' });
    }

    try {
        const clientResult = await pool.query(
            'SELECT id, name, address, identifier FROM customers WHERE identifier = $1', 
            [identifier]
        );
        const client = clientResult.rows[0];

        if (!client) {
            return res.status(404).json({ error: 'Cliente não encontrado.' });
        }

        res.json({
            id: client.id,
            name: client.name,
            address: client.address
        });

    } catch (err) {
        console.error('Erro em GET /clients/search:', err);
        res.status(500).json({ error: 'Erro interno do servidor ao buscar cliente.', details: err.message });
    }
});


// ===============================================
// 6️⃣ Rota: Vendedora cria ticket (Somente Cadastro)
// ===============================================
app.post('/ticket', async (req, res) => {
    // Campos que vêm do Flutter
    const { title, description, priority, requestedBy, clientId } = req.body; 

    if (!title || !description || !priority || !requestedBy || !clientId) {
        return res.status(400).json({ error: 'Todos os campos de ticket e o ID do cliente são obrigatórios.' });
    }

    try {
        // 1. Busca os dados do cliente para preencher os campos de endereço/nome
        const clientRes = await pool.query(
            'SELECT name, address FROM customers WHERE id = $1',
            [clientId]
        );
        const client = clientRes.rows[0];

        if (!client) {
            return res.status(404).json({ error: 'Cliente com ID informado não existe.' });
        }

        // 2. Insere o novo ticket com approved=false e assigned_to=null (PENDENTE)
        const result = await pool.query(
            `INSERT INTO tickets 
             (title, description, priority, customer_id, customer_name, customer_address, requested_by, approved, assigned_to) 
             VALUES ($1, $2, $3, $4, $5, $6, $7, false, NULL) RETURNING *`,
            [
                title, 
                description, 
                priority, 
                clientId, 
                client.name, 
                client.address, 
                requestedBy 
            ]
        );

        res.status(201).json({ ticket: result.rows[0] });
    } catch (err) {
        console.error('Erro em POST /ticket:', err);
        res.status(500).json({ error: 'Erro ao criar ticket', details: err.message });
    }
});


// ===============================================
// 7️⃣ Rota: Administrativo aprova ticket + Notificação FCM (COM VERIFICAÇÃO DE CARGO E TRANSAÇÃO)
// ===============================================
app.put('/tickets/:id/approve', async (req, res) => {
    const ticketId = req.params.id;
    // admin_id é o usuário que está tentando aprovar
    const { admin_id, assigned_to } = req.body; 

    const client = await pool.connect(); 

    try {
        await client.query('BEGIN');
        
        // 🚨 PASSO DE SEGURANÇA: VERIFICAR SE O admin_id TEM CARGO 'admin'
        const userRes = await client.query(
            'SELECT role FROM users WHERE id = $1',
            [admin_id]
        );
        const approver = userRes.rows[0];

        if (!approver || approver.role !== 'admin') {
            await client.query('ROLLBACK');
            // Retorna 403 Forbidden (Acesso negado)
            return res.status(403).json({ error: 'Apenas usuários com o cargo de admin podem aprovar tickets.' });
        }
        
        // 1. Atualiza o ticket
        const update = await client.query(
            // approved é setado para true, e o assigned_to é definido.
            `UPDATE tickets 
             SET approved = true, approved_by = $1, approved_at = now(), assigned_to = $2
             WHERE id = $3 RETURNING *`,
            [admin_id, assigned_to, ticketId]
        );

        const ticket = update.rows[0];

        if (!ticket) {
            await client.query('ROLLBACK');
            return res.status(404).json({ error: 'Ticket não encontrado.' });
        }

        // 2. Busca o fcm_token do técnico
        const techRes = await client.query(
            'SELECT fcm_token, name FROM users WHERE id = $1',
            [assigned_to]
        );
        const tech = techRes.rows[0];
        let notification_sent = false;

        // 3. Envia notificação FCM (O erro aqui não deve anular a aprovação do ticket no DB)
        if (tech && tech.fcm_token) {
            const message = {
                token: tech.fcm_token,
                notification: {
                    title: '🛠 Novo chamado de instalação aprovado!',
                    body: `Cliente: ${ticket.customer_name}, Endereço: ${ticket.customer_address}`
                },
                data: {
                    ticket_id: ticket.id.toString(),
                    action: 'new_ticket'
                }
            };
            try {
                await adminFirebase.messaging().send(message); 
                console.log(`Notificação enviada com sucesso para o técnico ID ${assigned_to}`);
                notification_sent = true;
            } catch (fcmError) {
                 // Loga o erro, mas a transação do DB continua para o COMMIT
                console.error(`Falha ao enviar notificação FCM para o técnico ID ${assigned_to}:`, fcmError.message);
            }
        } else {
            console.warn(`Token FCM não encontrado ou inválido para o técnico ID ${assigned_to}`);
        }

        await client.query('COMMIT');
        res.json({ ticket, notification_sent });

    } catch (err) {
        await client.query('ROLLBACK');
        console.error('Erro crítico em PUT /tickets/:id/approve (Transação):', err);
        res.status(500).json({ error: 'Erro ao aprovar ticket e enviar notificação', details: err.message });
    } finally {
        client.release();
    }
});

// ===============================================
// 8️⃣ Rota: Técnico lista tickets aprovados (Somente approved = true)
// ===============================================
app.get('/tickets/assigned/:tech_id', async (req, res) => {
    const techId = req.params.tech_id;

    try {
        const result = await pool.query(
            // Filtra EXATAMENTE: approved = true E assigned_to é o ID do técnico
            'SELECT * FROM tickets WHERE approved = true AND assigned_to = $1 ORDER BY created_at DESC',
            [techId]
        );
        res.json({ tickets: result.rows });
    } catch (err) {
        console.error('Erro em GET /tickets/assigned/:tech_id:', err);
        res.status(500).json({ error: 'Erro ao listar tickets' });
    }
});


// ===============================================
// 🚨 9️⃣ Middleware de Tratamento de Erro Centralizado (Deve ser o último)
// ===============================================
// Captura erros que não foram tratados nas rotas (erros internos do Express)
app.use((err, req, res, next) => {
    console.error('Tratador de Erro Geral:', err.stack);
    // Para erros sem status definido (erros 500)
    const statusCode = err.statusCode || 500;
    res.status(statusCode).json({
        error: 'Erro interno inesperado no servidor.',
        message: err.message
    });
});


// ===============================================
// Inicialização do Servidor
// ===============================================
app.listen(PORT, () => {
    console.log(`Servidor Express rodando na porta ${PORT}`);
    console.log(`Para testar, use: http://localhost:${PORT}`);
});
