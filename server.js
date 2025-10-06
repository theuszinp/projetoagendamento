// =====================================================================

// 1. CARREGAR VARIÁVEIS DE AMBIENTE (DEVE SER O PRIMEIRO!)
require('dotenv').config();

// 2. IMPORTAR LIBS
const express = require('express');
const bodyParser = require('body-parser');
const path = require('path');

// 3. IMPORTAR MÓDULOS (QUE AGORA CONSEGUEM LER O .env)
const pool = require('./db');
// Checa se o arquivo firebase.js existe antes de tentar importar (apenas para ambiente com FCM)
const adminFirebase = require.resolve('./firebase') ? require('./firebase') : null;

const app = express();
// Se estiver rodando localmente, use 3000. No Render, ele usará a variável PORT.
const PORT = process.env.PORT || 3000;

// Middleware para processar JSON nas requisições
app.use(bodyParser.json());

// ===============================================
// ROTAS VÁLIDAS DO SERVIDOR
// ===============================================

// 1️⃣ Rota Raiz (Health Check)
app.get('/', (req, res) => {
    // Rota simples para verificar se o servidor está ativo
    res.status(200).json({ status: 'ok', service: 'Ticket Management API', version: '1.0', server_time: new Date() });
});

// 2️⃣ Rota: LISTAR TODOS OS USUÁRIOS (NECESSÁRIO PARA ADMIN)
app.get('/users', async (req, res) => {
    // 🚨 ATENÇÃO: Em produção, você deve incluir uma verificação de segurança (role !== 'admin')
    try {
        const result = await pool.query(
            'SELECT id, name, email, role FROM users ORDER BY name ASC'
        );
        res.json({ users: result.rows });
    } catch (err) {
        console.error('Erro em GET /users:', err);
        res.status(500).json({ error: 'Erro ao listar usuários.' });
    }
});

// 🆕 Rota 2.1: LISTAR SOMENTE TÉCNICOS (Otimizado para dropdown)
app.get('/technicians', async (req, res) => {
    // 🚨 ATENÇÃO: Em produção, você deve incluir uma verificação de segurança (role !== 'admin')
    try {
        const result = await pool.query(
            // Filtra apenas usuários com role = 'tech' e retorna só o essencial
            "SELECT id, name FROM users WHERE role = 'tech' ORDER BY name ASC"
        );
        // Retorna um array de técnicos
        res.json({ technicians: result.rows });
    } catch (err) {
        console.error('Erro em GET /technicians:', err);
        res.status(500).json({ error: 'Erro ao listar técnicos.' });
    }
});


// 3️⃣ Rota: LISTAR TODOS OS TICKETS (NECESSÁRIO PARA ADMIN)
// Admin vê todos os tickets, independentemente do status (PENDING, APPROVED, REJECTED)
app.get('/tickets', async (req, res) => {
    // 🚨 ATENÇÃO: Em produção, você deve incluir uma verificação de segurança (role !== 'admin')
    try {
        // Exemplo de JOIN para trazer o nome do técnico atribuído
        const result = await pool.query(
            `SELECT
                t.*,
                u.name AS assigned_to_name
             FROM tickets t
             LEFT JOIN users u ON t.assigned_to = u.id
             ORDER BY t.created_at DESC`
        );
        // O Flutter espera { tickets: [...] }
        res.json({ tickets: result.rows });
    } catch (err) {
        console.error('Erro em GET /tickets:', err);
        res.status(500).json({ error: 'Erro ao listar todos os tickets.' });
    }
});


// 🆕 Rota 3.1: LISTAR TICKETS POR SOLICITANTE (PARA VENDEDOR)
// O vendedor vê todos os tickets que ele criou, com seus status.
app.get('/tickets/requested/:requested_by_id', async (req, res) => {
    const requestedById = req.params.requested_by_id;

    try {
        const result = await pool.query(
            // Filtra tickets onde o ID do solicitante bate com o ID na URL
            `SELECT
                t.*,
                u.name AS assigned_to_name
             FROM tickets t
             LEFT JOIN users u ON t.assigned_to = u.id
             WHERE t.requested_by = $1
             ORDER BY t.created_at DESC`,
            [requestedById]
        );
        // Vendedor consegue ver PENDING, APPROVED, REJECTED
        res.json({ tickets: result.rows });
    } catch (err) {
        console.error('Erro em GET /tickets/requested/:requested_by_id:', err);
        res.status(500).json({ error: 'Erro ao listar tickets solicitados.' });
    }
});


// 4️⃣ Rota: Login de Usuário
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

        // 🚨 SEGURANÇA CRÍTICA: ESTA COMPARAÇÃO DEVE SER MUDADA EM PRODUÇÃO!
        const isMatch = senha === user.password_hash;

        if (!isMatch) {
            return res.status(401).json({ error: 'Credenciais inválidas.' });
        }

        // Retorna os dados do usuário + um token JWT real em produção
        res.json({
            id: user.id,
            name: user.name,
            email: user.email,
            role: user.role,
        });

    } catch (err) {
        console.error('Erro em POST /login:', err);
        res.status(500).json({ error: 'Erro interno do servidor ao tentar login.', details: err.message });
    }
});

// 5️⃣ Rota: BUSCA DE CLIENTE (POR IDENTIFIER - CPF/CNPJ)
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


// 6️⃣ Rota: Vendedora cria ticket (Suporte a Cliente Novo/Existente)
app.post('/ticket', async (req, res) => {
    const { title, description, priority, requestedBy, clientId, customerName, address, identifier } = req.body;

    if (!title || !description || !priority || !requestedBy || !customerName || !address) {
        return res.status(400).json({ error: 'Campos essenciais (título, descrição, prioridade, solicitante, nome e endereço) são obrigatórios.' });
    }

    const clientDB = await pool.connect();
    let finalClientId = clientId;

    try {
        await clientDB.query('BEGIN'); // Inicia a transação

        // Lógica de Cliente NOVO
        if (!clientId) {
            if (!identifier) {
                await clientDB.query('ROLLBACK');
                return res.status(400).json({ error: 'O identificador (CPF/CNPJ) é obrigatório para cadastrar um novo cliente.' });
            }

            // Garante que o identificador (CPF/CNPJ) não existe ainda para evitar duplicidade
            const existingIdResult = await clientDB.query(
                'SELECT id FROM customers WHERE identifier = $1',
                [identifier]
            );

            if (existingIdResult.rows.length > 0) {
                 await clientDB.query('ROLLBACK');
                 return res.status(409).json({ error: `O identificador ${identifier} já está cadastrado em nossa base.` });
            }

            // Cria o novo cliente
            const newClientResult = await clientDB.query(
                'INSERT INTO customers (name, address, identifier) VALUES ($1, $2, $3) RETURNING id',
                [customerName, address, identifier]
            );
            finalClientId = newClientResult.rows[0].id;

        } else {
            // Lógica de Cliente EXISTENTE (clientId foi fornecido)
            const existingClient = await clientDB.query(
                'SELECT id FROM customers WHERE id = $1',
                [clientId]
            );
            if (existingClient.rows.length === 0) {
                await clientDB.query('ROLLBACK');
                return res.status(404).json({ error: 'Cliente existente não encontrado com o ID fornecido.' });
            }

            // 💡 MELHORIA: Atualiza o nome e endereço do cliente na tabela principal com os dados mais recentes da vendedora
            await clientDB.query(
                'UPDATE customers SET name = $1, address = $2 WHERE id = $3',
                [customerName, address, clientId]
            );
            finalClientId = clientId;
        }

        // Insere o novo ticket com status PENDING
        const result = await clientDB.query(
            `INSERT INTO tickets
             (title, description, priority, customer_id, customer_name, customer_address, requested_by, assigned_to, status)
             VALUES ($1, $2, $3, $4, $5, $6, $7, NULL, 'PENDING') RETURNING *`,
            [
                title,
                description,
                priority,
                finalClientId, // ID do cliente (novo ou existente)
                customerName,
                address,
                requestedBy
            ]
        );

        await clientDB.query('COMMIT'); // Finaliza a transação com sucesso
        res.status(201).json({ ticket: result.rows[0] });

    } catch (err) {
        await clientDB.query('ROLLBACK'); // Desfaz tudo em caso de erro
        console.error('Erro em POST /ticket (Transação):', err);
        // Trata o erro 409 de conflito se for o caso
        if (err.code === '23505') { // Código de erro do PostgreSQL para violação de unique constraint
            return res.status(409).json({ error: `O identificador (CPF/CNPJ) já está cadastrado em nossa base.` });
        }
        res.status(500).json({ error: 'Erro interno do servidor ao criar ticket. Tente novamente.', details: err.message });
    } finally {
        clientDB.release();
    }
});


// 7️⃣ Rota: Administrativo aprova ticket + Atribuição de Técnico + Notificação FCM
// Esta rota agora garante que o assigned_to não é nulo/inválido, resolvendo o problema do botão cinza/clique.
app.put('/tickets/:id/approve', async (req, res) => {
    const ticketId = req.params.id;
    const { admin_id, assigned_to } = req.body;

    const client = await pool.connect();

    try {
        await client.query('BEGIN');

        // 🚨 PASSO 1: VERIFICAR ADMIN
        const userRes = await client.query(
            'SELECT role FROM users WHERE id = $1',
            [admin_id]
        );
        const approver = userRes.rows[0];

        if (!approver || approver.role !== 'admin') {
            await client.query('ROLLBACK');
            return res.status(403).json({ error: 'Apenas usuários com o cargo de admin podem aprovar tickets.' });
        }

        // 🚨 PASSO 2: VERIFICAR E GARANTIR QUE UM TÉCNICO VÁLIDO FOI ATRIBUÍDO
        if (!assigned_to) {
            await client.query('ROLLBACK');
            // Retorna 400 para o Flutter saber que falta a seleção do técnico
            return res.status(400).json({ error: 'O ID do técnico para atribuição é obrigatório para aprovar o ticket.' });
        }

        const techResCheck = await client.query(
            'SELECT id FROM users WHERE id = $1 AND role = \'tech\'',
            [assigned_to]
        );
        if (techResCheck.rows.length === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({
                error: `Técnico com ID ${assigned_to} não encontrado ou não tem o cargo 'tech'.`,
            });
        }

        // 3. Atualiza o ticket: define status como 'APPROVED' e atribui o técnico
        const update = await client.query(
            `UPDATE tickets
             SET status = 'APPROVED', approved_by = $1, approved_at = now(), assigned_to = $2
             WHERE id = $3 RETURNING *`,
            [admin_id, assigned_to, ticketId]
        );

        const ticket = update.rows[0];

        if (!ticket) {
            await client.query('ROLLBACK');
            return res.status(404).json({ error: 'Ticket não encontrado.' });
        }

        // 4. Lógica de Notificação FCM (Mantida como placeholder)
        let notification_sent = false;

        if (adminFirebase && assigned_to) {
            const techRes = await client.query(
                'SELECT fcm_token, name FROM users WHERE id = $1',
                [assigned_to]
            );
            const tech = techRes.rows[0];

            // 5. Envia notificação FCM
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
                    // await adminFirebase.messaging().send(message);
                    notification_sent = true;
                } catch (fcmError) {
                    console.error(`Falha ao enviar notificação FCM para o técnico ID ${assigned_to}:`, fcmError.message);
                }
            } else {
                console.warn(`Token FCM não encontrado ou inválido para o técnico ID ${assigned_to}`);
            }
        } else {
            console.warn('Módulo Firebase não carregado ou técnico não atribuído. Pulando notificação FCM.');
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

// 🆕 Rota 8️⃣: Administrativo REJEITA/REPROVA ticket
// Muda o status para REJECTED e remove a atribuição, retornando o ticket ao vendedor.
app.put('/tickets/:id/reject', async (req, res) => {
    const ticketId = req.params.id;
    const { admin_id } = req.body;

    // Em um cenário real, você faria a checagem do admin_id aqui também.
    // ...

    try {
        const result = await pool.query(
            // Mudar status para REJECTED e remover atribuição de técnico (NULL)
            `UPDATE tickets
             SET status = 'REJECTED', approved_by = $1, approved_at = now(), assigned_to = NULL
             WHERE id = $2 RETURNING *`,
            [admin_id, ticketId]
        );

        const ticket = result.rows[0];

        if (!ticket) {
            return res.status(404).json({ error: 'Ticket não encontrado para ser reprovado.' });
        }

        // Retorna o ticket atualizado com o novo status
        res.status(200).json({
            message: `Ticket ID ${ticketId} foi reprovado com sucesso e seu status foi atualizado para REJECTED.`,
            ticket: ticket
        });

    } catch (err) {
        console.error('Erro em PUT /tickets/:id/reject:', err);
        res.status(500).json({ error: 'Erro ao reprovar ticket.', details: err.message });
    }
});


// 9️⃣ Rota: Técnico lista tickets aprovados (Somente status = 'APPROVED')
app.get('/tickets/assigned/:tech_id', async (req, res) => {
    const techId = req.params.tech_id;

    try {
        const result = await pool.query(
            // Filtra tickets com status 'APPROVED' E atribuído ao técnico
            `SELECT
                t.*,
                u.name AS approved_by_admin_name
             FROM tickets t
             LEFT JOIN users u ON t.approved_by = u.id
             WHERE t.status = 'APPROVED' AND t.assigned_to = $1
             ORDER BY t.created_at DESC`,
            [techId]
        );
        res.json({ tickets: result.rows });
    } catch (err) {
        console.error('Erro em GET /tickets/assigned/:tech_id:', err);
        res.status(500).json({ error: 'Erro ao listar tickets' });
    }
});


// ===============================================
// MIDDLEWARES DE TRATAMENTO DE ERRO (CRÍTICO PARA O FLUTTER)
// ===============================================

// 🚨 TRATAMENTO DE ROTA NÃO ENCONTRADA (404)
// Este DEVE vir após todas as rotas válidas
app.use((req, res, next) => {
    // Se chegou até aqui, nenhuma rota definida acima correspondeu
    // Retorna JSON para que o Flutter consiga decodificar o erro 404
    res.status(404).json({
        error: "Rota não encontrada",
        message: `O recurso ${req.originalUrl} usando o método ${req.method} não existe ou a URL está incorreta.`
    });
});


// 🚨 MIDDLEWARE DE TRATAMENTO DE ERRO CENTRALIZADO (500)
// Este DEVE ser o ÚLTIMO middleware, antes do app.listen()
app.use((err, req, res, next) => {
    console.error('Tratador de Erro Geral (500):', err.stack);
    const statusCode = err.statusCode || 500;

    // Garante que a resposta de erro é JSON
    res.status(statusCode).json({
        error: 'Erro interno inesperado no servidor.',
        message: err.message,
        path: req.originalUrl
    });
});


// ===============================================
// Inicialização do Servidor
// ===============================================
app.listen(PORT, () => {
    console.log(`Servidor Express rodando na porta ${PORT}`);
    console.log(`Para testar, use: http://localhost:${PORT}`);
    // O log da Base URL foi corrigido para não ter caracteres invisíveis
    console.log(`Base URL: ${process.env.RENDER_EXTERNAL_URL || `http://localhost:${PORT}`}`);
});
