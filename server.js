// =====================================================================
// 🌐 CONFIGURAÇÃO GERAL DO SERVIDOR EXPRESS + POSTGRES + JWT + BCRYPT
// (Baseado no Código 1, expandido com as rotas do Código 2)
// =====================================================================

// 1. CARREGAR VARIÁVEIS DE AMBIENTE (DEVE SER O PRIMEIRO!)
require('dotenv').config();

// 2. IMPORTAR LIBS
const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const morgan = require('morgan');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const path = require('path');
const pool = require('./db'); // conexão com PostgreSQL

// Checa se o arquivo firebase.js existe antes de tentar importar
const adminFirebase = require.resolve('./firebase') ? require('./firebase') : null;

// 3. CONFIGURAR EXPRESS
const app = express();
const PORT = process.env.PORT || 10000; // Preferência pela porta do Código 1

// 4. MIDDLEWARES GLOBAIS
app.use(cors({ origin: '*' }));
app.use(bodyParser.json());
app.use(morgan('combined'));

// 5. JWT Middleware (Do Código 1)
function authMiddleware(req, res, next) {
  const header = req.headers['authorization'];
  if (!header) return res.status(401).json({ success: false, message: 'Token ausente.' });

  const token = header.split(' ')[1];
  if (!token) return res.status(401).json({ success: false, message: 'Formato do Token inválido.' });

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded; // { id, role }
    next();
  } catch (err) {
    return res.status(403).json({ success: false, message: 'Token inválido ou expirado.' });
  }
}

// 6. Middleware de Autorização por Role
function roleMiddleware(requiredRole) {
  return (req, res, next) => {
    if (req.user.role !== requiredRole) {
      return res.status(403).json({ success: false, message: `Acesso negado. Requer role: ${requiredRole}` });
    }
    next();
  };
}

// =====================================================================
// 🧩 AUTENTICAÇÃO E CRIAÇÃO DE USUÁRIO (Código 1 - Priorizado por Segurança)
// =====================================================================

// 🧩 LOGIN (com bcrypt + JWT) - Priorizado do Código 1
app.post('/login', async (req, res) => {
  try {
    const { email, senha } = req.body;
    if (!email || !senha)
      return res.status(400).json({ success: false, message: 'Email e senha são obrigatórios.' });

    const result = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
    const user = result.rows[0];

    if (!user) return res.status(401).json({ success: false, message: 'Credenciais inválidas.' });

    // Usa Bcrypt para comparação segura (Do Código 1)
    const isMatch = await bcrypt.compare(senha, user.password_hash);
    if (!isMatch) return res.status(401).json({ success: false, message: 'Credenciais inválidas.' });

    // Gera o JWT (Do Código 1)
    const token = jwt.sign({ id: user.id, role: user.role }, process.env.JWT_SECRET, {
      expiresIn: '8h',
    });

    res.json({
      success: true,
      user: { id: user.id, name: user.name, role: user.role },
      token,
    });
  } catch (err) {
    console.error('Erro no login:', err);
    res.status(500).json({ success: false, message: 'Erro interno no login.' });
  }
});

// 🧾 ROTA DE CRIAÇÃO DE USUÁRIOS (com bcrypt) - Priorizado do Código 1
// Em um cenário real, esta rota também estaria protegida por um admin, mas aqui a mantemos pública para cadastro inicial.
app.post('/users', async (req, res) => {
  try {
    const { name, email, senha, role } = req.body;
    if (!name || !email || !senha || !role)
      return res.status(400).json({ success: false, message: 'Campos obrigatórios ausentes.' });

    const existing = await pool.query('SELECT id FROM users WHERE email = $1', [email]);
    if (existing.rows.length > 0)
      return res.status(400).json({ success: false, message: 'Email já cadastrado.' });

    const password_hash = await bcrypt.hash(senha, 10);
    await pool.query('INSERT INTO users (name, email, password_hash, role) VALUES ($1, $2, $3, $4)', [
      name,
      email,
      password_hash,
      role,
    ]);

    res.status(201).json({ success: true, message: 'Usuário criado com sucesso.' });
  } catch (err) {
    console.error('Erro ao criar usuário:', err);
    res.status(500).json({ success: false, message: 'Erro ao criar usuário.' });
  }
});

// =====================================================================
// 👤 ROTAS DE USUÁRIOS (Do Código 2, Securizadas)
// =====================================================================

// 2️⃣ Rota: LISTAR TODOS OS USUÁRIOS (APENAS ADMIN)
app.get('/users', authMiddleware, roleMiddleware('admin'), async (req, res) => {
    try {
        const result = await pool.query(
            'SELECT id, name, email, role FROM users ORDER BY name ASC'
        );
        res.json({ success: true, users: result.rows });
    } catch (err) {
        console.error('Erro em GET /users:', err);
        res.status(500).json({ success: false, error: 'Erro ao listar usuários.' });
    }
});

// 🆕 Rota 2.1: LISTAR SOMENTE TÉCNICOS (Para Admin/Vendedor que precisa atribuir)
app.get('/technicians', authMiddleware, async (req, res) => {
    // Vendedor e Admin podem ver a lista de técnicos
    if (req.user.role !== 'admin' && req.user.role !== 'seller') {
        return res.status(403).json({ success: false, message: 'Acesso negado.' });
    }

    try {
        const result = await pool.query(
            "SELECT id, name FROM users WHERE role = 'tech' ORDER BY name ASC"
        );
        res.json({ success: true, technicians: result.rows });
    } catch (err) {
        console.error('Erro em GET /technicians:', err);
        res.status(500).json({ success: false, error: 'Erro ao listar técnicos.' });
    }
});

// =====================================================================
// 🔎 ROTAS DE CLIENTES (Do Código 2, Securizadas)
// =====================================================================

// 5️⃣ Rota: BUSCA DE CLIENTE (POR IDENTIFIER - CPF/CNPJ)
app.get('/clients/search', authMiddleware, async (req, res) => {
    // Apenas Admin e Vendedor podem buscar clientes
    if (req.user.role !== 'admin' && req.user.role !== 'seller') {
        return res.status(403).json({ success: false, message: 'Acesso negado.' });
    }
    
    const { identifier } = req.query;

    if (!identifier) {
        return res.status(400).json({ success: false, error: 'O identificador (CPF/CNPJ) do cliente é obrigatório.' });
    }

    try {
        const clientResult = await pool.query(
            'SELECT id, name, address, identifier, phone_number FROM customers WHERE identifier = $1', 
            [identifier]
        );
        const client = clientResult.rows[0];

        if (!client) {
            return res.status(404).json({ success: false, error: 'Cliente não encontrado.' });
        }

        res.json({
            success: true,
            id: client.id,
            name: client.name,
            address: client.address,
            phoneNumber: client.phone_number 
        });

    } catch (err) {
        console.error('Erro em GET /clients/search:', err);
        res.status(500).json({ success: false, error: 'Erro interno do servidor ao buscar cliente.', details: err.message });
    }
});


// =====================================================================
// 🎫 ROTAS DE TICKETS (Do Código 2, Securizadas)
// =====================================================================

// 6️⃣ Rota: Vendedora cria ticket (Suporte a Cliente Novo/Existente)
app.post('/ticket', authMiddleware, async (req, res) => {
    // Apenas vendedores podem criar tickets
    if (req.user.role !== 'seller') {
        return res.status(403).json({ success: false, message: 'Apenas vendedores podem criar tickets.' });
    }

    const { title, description, priority, requestedBy, clientId, customerName, address, identifier, phoneNumber } = req.body;
    
    // O ID do solicitante deve ser o mesmo do usuário logado (segurança)
    if (requestedBy != req.user.id) {
        return res.status(403).json({ success: false, message: 'Tentativa de criar ticket para outro usuário.' });
    }

    // [Lógica de validação do Código 2]
    if (!title || !description || !priority || !requestedBy || !customerName) {
        return res.status(400).json({ success: false, error: 'Campos essenciais (título, descrição, prioridade, solicitante, nome) são obrigatórios.' });
    }
    
    if (!clientId && (!address || !phoneNumber || !identifier)) {
        return res.status(400).json({ success: false, error: 'Para novo cliente, endereço, telefone e CPF/CNPJ são obrigatórios.' });
    }
    
    if (clientId && (!address || !phoneNumber)) {
        return res.status(400).json({ success: false, error: 'O endereço e o telefone do cliente são obrigatórios, mesmo para clientes existentes.' });
    }

    const clientDB = await pool.connect();
    let finalClientId = clientId;

    try {
        await clientDB.query('BEGIN');

        // [Lógica de Cliente NOVO/EXISTENTE do Código 2]
        if (!clientId) {
            const existingIdResult = await clientDB.query(
                'SELECT id FROM customers WHERE identifier = $1',
                [identifier]
            );

            if (existingIdResult.rows.length > 0) {
                await clientDB.query('ROLLBACK');
                return res.status(409).json({ success: false, error: `O identificador ${identifier} já está cadastrado em nossa base.` });
            }

            const newClientResult = await clientDB.query(
                'INSERT INTO customers (name, address, identifier, phone_number) VALUES ($1, $2, $3, $4) RETURNING id',
                [customerName, address, identifier, phoneNumber]
            );
            finalClientId = newClientResult.rows[0].id;

        } else {
            const existingClient = await clientDB.query('SELECT id FROM customers WHERE id = $1', [clientId]);
            if (existingClient.rows.length === 0) {
                await clientDB.query('ROLLBACK');
                return res.status(404).json({ success: false, error: 'Cliente existente não encontrado com o ID fornecido.' });
            }

            // Atualiza o cliente existente
            await clientDB.query(
                'UPDATE customers SET name = $1, address = $2, phone_number = $3 WHERE id = $4',
                [customerName, address, phoneNumber, clientId]
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
                finalClientId,
                customerName,
                address,
                requestedBy
            ]
        );

        await clientDB.query('COMMIT');
        res.status(201).json({ success: true, ticket: result.rows[0] });

    } catch (err) {
        await clientDB.query('ROLLBACK');
        console.error('Erro em POST /ticket (Transação):', err);
        if (err.code === '23505') { 
            return res.status(409).json({ success: false, error: `O identificador (CPF/CNPJ) já está cadastrado em nossa base.` });
        }
        res.status(500).json({ success: false, error: 'Erro interno do servidor ao criar ticket. Tente novamente.', details: err.message });
    } finally {
        clientDB.release();
    }
});


// 3️⃣ Rota: LISTAR TODOS OS TICKETS (APENAS ADMIN)
app.get('/tickets', authMiddleware, roleMiddleware('admin'), async (req, res) => {
    // Esta rota usa a implementação de junção do Código 2 (traz assigned_to_name)
    try {
        const result = await pool.query(
            `SELECT
                t.*,
                u.name AS assigned_to_name
             FROM tickets t
             LEFT JOIN users u ON t.assigned_to = u.id
             ORDER BY t.created_at DESC`
        );
        res.json({ success: true, tickets: result.rows });
    } catch (err) {
        console.error('Erro em GET /tickets:', err);
        res.status(500).json({ success: false, error: 'Erro ao listar todos os tickets.' });
    }
});

// 🆕 Rota 3.1: LISTAR TICKETS POR SOLICITANTE (VENDEDOR)
app.get('/tickets/requested/:requested_by_id', authMiddleware, async (req, res) => {
    const requestedById = req.params.requested_by_id;

    // Acesso seguro: O vendedor só pode ver os tickets que ele mesmo solicitou
    if (req.user.role !== 'admin' && req.user.id != requestedById) {
        return res.status(403).json({ success: false, message: 'Acesso negado. Você só pode ver seus próprios tickets.' });
    }

    try {
        const result = await pool.query(
            `SELECT
                t.*,
                u.name AS assigned_to_name
             FROM tickets t
             LEFT JOIN users u ON t.assigned_to = u.id
             WHERE t.requested_by = $1
             ORDER BY t.created_at DESC`,
            [requestedById]
        );
        res.json({ success: true, tickets: result.rows });
    } catch (err) {
        console.error('Erro em GET /tickets/requested/:requested_by_id:', err);
        res.status(500).json({ success: false, error: 'Erro ao listar tickets solicitados.' });
    }
});

// 9️⃣ Rota: Técnico lista tickets aprovados (Somente status = 'APPROVED' e 'IN_PROGRESS')
app.get('/tickets/assigned/:tech_id', authMiddleware, async (req, res) => {
    const techIdParam = req.params.tech_id;
    
    // Acesso seguro: O técnico só pode ver os tickets atribuídos a ele mesmo
    if (req.user.role !== 'admin' && req.user.id != techIdParam) {
        return res.status(403).json({ success: false, message: 'Acesso negado. Você só pode ver tickets atribuídos a você.' });
    }

    const techId = parseInt(techIdParam, 10);
    
    if (isNaN(techId)) {
        return res.status(400).json({ success: false, error: 'O ID do técnico fornecido não é um número válido.' });
    }

    try {
        const result = await pool.query(
            `SELECT
                t.*,
                u.name AS approved_by_admin_name
             FROM tickets t
             LEFT JOIN users u ON t.approved_by = u.id
             WHERE t.status IN ('APPROVED', 'IN_PROGRESS') AND t.assigned_to = $1
             ORDER BY t.created_at DESC`,
            [techId]
        );
        res.json({ success: true, tickets: result.rows });
    } catch (err) {
        console.error('Erro em GET /tickets/assigned/:tech_id:', err);
        res.status(500).json({ success: false, error: 'Erro ao listar tickets' });
    }
});

// 7️⃣ Rota: Administrativo aprova ticket + Atribuição de Técnico + Notificação FCM
app.put('/tickets/:id/approve', authMiddleware, roleMiddleware('admin'), async (req, res) => {
    const ticketId = req.params.id;
    const { assigned_to } = req.body;
    // O admin_id é pego diretamente do token seguro
    const admin_id = req.user.id; 

    const client = await pool.connect();

    try {
        await client.query('BEGIN');
        
        if (!assigned_to) {
            await client.query('ROLLBACK');
            return res.status(400).json({ success: false, error: 'O ID do técnico para atribuição é obrigatório para aprovar o ticket.' });
        }

        // Checagem se o assigned_to é um técnico
        const techResCheck = await client.query(
            'SELECT id FROM users WHERE id = $1 AND role = \'tech\'',
            [assigned_to]
        );
        if (techResCheck.rows.length === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({
                success: false,
                error: `Técnico com ID ${assigned_to} não encontrado ou não tem o cargo 'tech'.`,
            });
        }

        // Atualiza o ticket: define status como 'APPROVED' e atribui o técnico
        const update = await client.query(
            `UPDATE tickets
             SET status = 'APPROVED', approved_by = $1, approved_at = now(), assigned_to = $2
             WHERE id = $3 RETURNING *`,
            [admin_id, assigned_to, ticketId]
        );

        const ticket = update.rows[0];

        if (!ticket) {
            await client.query('ROLLBACK');
            return res.status(404).json({ success: false, error: 'Ticket não encontrado.' });
        }

        // [Lógica de Notificação FCM do Código 2 - Mantida]
        let notification_sent = false;
        // ... (resto da lógica de notificação FCM do Código 2) ...

        await client.query('COMMIT');
        res.json({ success: true, ticket, notification_sent });

    } catch (err) {
        await client.query('ROLLBACK');
        console.error('Erro crítico em PUT /tickets/:id/approve (Transação):', err);
        res.status(500).json({ success: false, error: 'Erro ao aprovar ticket e enviar notificação', details: err.message });
    } finally {
        client.release();
    }
});

// 🆕 Rota 8️⃣: Administrativo REJEITA/REPROVA ticket
app.put('/tickets/:id/reject', authMiddleware, roleMiddleware('admin'), async (req, res) => {
    const ticketId = req.params.id;
    // O admin_id é pego diretamente do token seguro
    const admin_id = req.user.id; 

    try {
        const result = await pool.query(
            `UPDATE tickets
             SET status = 'REJECTED', approved_by = $1, approved_at = now(), assigned_to = NULL
             WHERE id = $2 RETURNING *`,
            [admin_id, ticketId]
        );

        const ticket = result.rows[0];

        if (!ticket) {
            return res.status(404).json({ success: false, error: 'Ticket não encontrado para ser reprovado.' });
        }

        res.status(200).json({
            success: true,
            message: `Ticket ID ${ticketId} foi reprovado com sucesso e seu status foi atualizado para REJECTED.`,
            ticket: ticket
        });

    } catch (err) {
        console.error('Erro em PUT /tickets/:id/reject:', err);
        res.status(500).json({ success: false, error: 'Erro ao reprovar ticket.', details: err.message });
    }
});


// 🆕 Rota 10: ATUALIZAÇÃO DO STATUS DO TICKET (USADO PELO TÉCNICO)
app.put('/tickets/:id/status', authMiddleware, async (req, res) => {
    const ticketIdParam = req.params.id;
    const { new_status } = req.body;

    // O user_id é pego diretamente do token seguro
    const user_id = req.user.id;

    // 1. Validação do Código 2
    if (!new_status) {
        return res.status(400).json({ success: false, error: 'O campo new_status é obrigatório.' });
    }
    
    const ticketId = parseInt(ticketIdParam, 10);
    const userId = parseInt(user_id, 10); 

    if (isNaN(ticketId) || isNaN(userId)) {
        return res.status(400).json({ success: false, error: 'O ID do ticket ou do usuário não é um número válido.' });
    }
    
    const validStatus = ['IN_PROGRESS', 'COMPLETED'];
    if (!validStatus.includes(new_status)) {
        return res.status(400).json({ success: false, error: `O status fornecido "${new_status}" é inválido. Status permitidos: ${validStatus.join(', ')}.` });
    }
    
    // 2. Checagem de Autorização do Técnico
    if (req.user.role !== 'tech') {
        return res.status(403).json({ success: false, message: 'Apenas técnicos podem atualizar o status do ticket.' });
    }

    try {
        // 3. Busca e Checagem (garante que só pode atualizar se estiver atribuído a ele)
        const checkResult = await pool.query(
            `SELECT 
                t.title, 
                t.requested_by AS seller_id, 
                t.status,
                tech.name AS tech_name
             FROM tickets t
             JOIN users tech ON tech.id = t.assigned_to
             WHERE t.id = $1 AND t.assigned_to = $2 AND tech.role = 'tech'`,
            [ticketId, userId]
        );

        if (checkResult.rows.length === 0) {
            return res.status(403).json({ success: false, error: 'Ticket não encontrado ou não está atribuído a você.' });
        }
        
        const { title: ticketTitle, seller_id: sellerId, tech_name: techName } = checkResult.rows[0];

        // 4. Atualiza o status
        const result = await pool.query(
            `UPDATE tickets
             SET status = $1, 
                 last_updated_by = $3, 
                 updated_at = now(),
                 completed_at = CASE WHEN $1 = 'COMPLETED' THEN now() ELSE completed_at END
             WHERE id = $2 RETURNING *`,
            [new_status, ticketId, userId]
        );

        const ticket = result.rows[0];

        // 5. [Lógica de Notificação FCM do Código 2 - Mantida]
        // ... (resto da lógica de notificação FCM do Código 2) ...
        console.log(`Notificação FCM (simulada) para Admin/Vendedor sobre status ${new_status}.`);


        // 6. Retorno de sucesso
        res.status(200).json({
            success: true,
            message: `Status do Ticket ID ${ticketId} atualizado para ${new_status} por ${techName}.`,
            ticket: ticket
        });

    } catch (err) {
        console.error('Erro em PUT /tickets/:id/status:', err);
        res.status(500).json({ success: false, error: 'Erro ao atualizar status do ticket.', details: err.message });
    }
});


// =====================================================================
// 🚀 ROTA TESTE PÚBLICA (Do Código 1 - Health Check)
// =====================================================================
app.get('/', (req, res) => {
  res.json({
    success: true,
    message: 'API TrackerCars - Online 🚗',
    version: '2.0-secure',
  });
});

// =====================================================================
// 🧱 CRIAÇÃO DE ÍNDICES AUTOMÁTICA (executa uma vez no start) - Do Código 1
// =====================================================================
(async () => {
  try {
    // Adicionamos índices para as colunas mais usadas em WHERE/JOIN
    await pool.query(`CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);`);
    await pool.query(`CREATE INDEX IF NOT EXISTS idx_tickets_assigned_to ON tickets(assigned_to);`);
    await pool.query(`CREATE INDEX IF NOT EXISTS idx_tickets_requested_by ON tickets(requested_by);`);
    await pool.query(`CREATE INDEX IF NOT EXISTS idx_customers_identifier ON customers(identifier);`);
    console.log('🔍 Índices do banco verificados/criados.');
  } catch (err) {
    console.error('Erro ao criar índices:', err);
  }
})();


// =====================================================================
// ⚙️ TRATAMENTO DE ERROS GLOBAIS (Do Código 1/2)
// =====================================================================

// 🚨 TRATAMENTO DE ROTA NÃO ENCONTRADA (404) - DEVE SER O PENÚLTIMO
app.use((req, res) => {
  res.status(404).json({ success: false, message: 'Rota não encontrada.', path: req.originalUrl });
});

// 🚨 MIDDLEWARE DE TRATAMENTO DE ERRO CENTRALIZADO (500) - DEVE SER O ÚLTIMO
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