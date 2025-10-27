const express = require('express');
const router = express.Router();
const pool = require('../db');
const fs = require('fs');
const path = require('path');
const { authMiddleware, roleMiddleware } = require('../server'); // Importa middlewares

// Tenta carregar firebase apenas se o arquivo existir
let adminFirebase = null;
try {
    const firebasePath = path.join(__dirname, '..', 'firebase.js');
    if (fs.existsSync(firebasePath)) {
        adminFirebase = require(firebasePath);
    }
} catch (e) {
    console.warn('Arquivo firebase não carregado:', e.message);
}

// =====================================================================
// ROTAS DE TICKETS (POST, GET, PUT)
// =====================================================================

// 6️⃣ Rota: Vendedora cria ticket (Suporte a Cliente Novo/Existente)
router.post('/', authMiddleware, async (req, res) => {
    if (req.user.role !== 'seller') {
        return res.status(403).json({ success: false, message: 'Apenas vendedores podem criar tickets.' });
    }
    
    const {
        title,
        description,
        priority,
        requestedBy,
        clientId,
        customerName,
        address,
        identifier,
        phoneNumber
    } = req.body;

    // Normaliza e valida IDs (evita comparação string/number)
    const numericRequestedBy = Number(requestedBy);
    if (Number.isNaN(numericRequestedBy)) {
        return res.status(400).json({ success: false, error: 'O campo requestedBy deve ser um ID numérico válido.' });
    }

    // Garante que o vendedor só possa criar tickets para si mesmo
    if (Number(req.user.id) !== numericRequestedBy) {
        return res.status(403).json({ success: false, message: 'Tentativa de criar ticket para outro usuário.' });
    }

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
            // valida numericidade do clientId
            const numericClientId = Number(clientId);
            if (Number.isNaN(numericClientId)) {
                await clientDB.query('ROLLBACK');
                return res.status(400).json({ success: false, error: 'clientId inválido.' });
            }

            const existingClient = await clientDB.query('SELECT id FROM customers WHERE id = $1', [numericClientId]);
            if (existingClient.rows.length === 0) {
                await clientDB.query('ROLLBACK');
                return res.status(404).json({ success: false, error: 'Cliente existente não encontrado com o ID fornecido.' });
            }

            await clientDB.query(
                'UPDATE customers SET name = $1, address = $2, phone_number = $3 WHERE id = $4',
                [customerName, address, phoneNumber, numericClientId]
            );
            finalClientId = numericClientId;
        }

        const sqlQuery = `INSERT INTO tickets
             (title, description, priority, customer_id, customer_name, customer_address, requested_by, assigned_to, status, tech_status)
             VALUES ($1, $2, $3, $4, $5, $6, $7, NULL, 'PENDING', NULL) RETURNING *`;

        // O cleanedQuery anterior era estranho (removendo caracteres não-ascii) — mantemos a query normal
        const result = await clientDB.query(
            sqlQuery, 
            [
                title,
                description,
                priority,
                finalClientId,
                customerName,
                address,
                numericRequestedBy
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
router.get('/', authMiddleware, roleMiddleware('admin'), async (req, res) => {
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
router.get('/requested/:requested_by_id', authMiddleware, async (req, res) => {
    const requestedByIdParam = req.params.requested_by_id;
    const requestedById = parseInt(requestedByIdParam, 10);

    if (isNaN(requestedById)) {
        return res.status(400).json({ success: false, error: 'O ID do solicitante deve ser um número válido.' });
    }

    // Se não for admin, só pode ver os próprios tickets
    if (req.user.role !== 'admin' && Number(req.user.id) !== requestedById) {
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

// 9️⃣ Rota: Técnico lista tickets aprovados
router.get('/assigned/:tech_id', authMiddleware, async (req, res) => {
    const techIdParam = req.params.tech_id;
    const techId = parseInt(techIdParam, 10);

    if (isNaN(techId)) {
        return res.status(400).json({ success: false, error: 'O ID do técnico fornecido não é um número válido.' });
    }

    if (req.user.role !== 'admin' && Number(req.user.id) !== techId) {
        return res.status(403).json({ success: false, message: 'Acesso negado. Você só pode ver tickets atribuídos a você.' });
    }

    try {
        const result = await pool.query(
            `SELECT
                t.*,
                u.name AS approved_by_admin_name
             FROM tickets t
             LEFT JOIN users u ON t.approved_by = u.id
             WHERE t.assigned_to = $1 AND (t.status = 'APPROVED' OR t.tech_status IN ('IN_PROGRESS', 'COMPLETED'))
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
router.put('/:id/approve', authMiddleware, roleMiddleware('admin'), async (req, res) => {
    const ticketId = parseInt(req.params.id, 10); 
    const { assigned_to } = req.body;
    const admin_id = Number(req.user.id);
    
    if (isNaN(ticketId)) {
        return res.status(400).json({ success: false, error: 'ID de ticket inválido.' });
    }

    if (!assigned_to) {
        return res.status(400).json({ success: false, error: 'O ID do técnico para atribuição é obrigatório para aprovar o ticket.' });
    }

    const numericAssignedTo = Number(assigned_to);
    if (Number.isNaN(numericAssignedTo)) {
        return res.status(400).json({ success: false, error: 'O ID do técnico deve ser numérico.' });
    }

    const client = await pool.connect();

    try {
        await client.query('BEGIN');

        const techResCheck = await client.query(
            'SELECT id FROM users WHERE id = $1 AND role = $2',
            [numericAssignedTo, 'tech']
        );
        if (techResCheck.rows.length === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({
                success: false,
                error: `Técnico com ID ${numericAssignedTo} não encontrado ou não tem o cargo 'tech'.`,
            });
        }

        const update = await client.query(
            `UPDATE tickets
             SET status = 'APPROVED', approved_by = $1, approved_at = now(), assigned_to = $2, tech_status = NULL
             WHERE id = $3 RETURNING *`,
            [admin_id, numericAssignedTo, ticketId]
        );

        const ticket = update.rows[0];

        if (!ticket) {
            await client.query('ROLLBACK');
            return res.status(404).json({ success: false, error: 'Ticket não encontrado.' });
        }

        let notification_sent = false;
        // Se você tem adminFirebase configurado -> enviar FCM aqui
        // Exemplo (pseudo):
        // if (adminFirebase && adminFirebase.messaging) {
        //     // montar payload e enviar
        //     notification_sent = true/false conforme resposta
        // }

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
router.put('/:id/reject', authMiddleware, roleMiddleware('admin'), async (req, res) => {
    const ticketId = parseInt(req.params.id, 10); 
    const admin_id = Number(req.user.id);
    
    if (isNaN(ticketId)) {
        return res.status(400).json({ success: false, error: 'ID de ticket inválido.' });
    }

    try {
        const result = await pool.query(
            `UPDATE tickets
             SET status = 'REJECTED', approved_by = $1, approved_at = now(), assigned_to = NULL, tech_status = NULL
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
router.put('/:id/tech-status', authMiddleware, async (req, res) => {
    const ticketIdParam = req.params.id;
    const { new_status } = req.body; 

    const userId = Number(req.user.id); 

    // 1. Validação e Coerção
    if (!new_status) {
        return res.status(400).json({ success: false, error: 'O campo new_status é obrigatório.' });
    }

    const ticketId = parseInt(ticketIdParam, 10); 
    if (isNaN(ticketId) || isNaN(userId)) {
        return res.status(400).json({ success: false, error: 'O ID do ticket ou do usuário não é um número válido.' });
    }

    const validStatus = ['IN_PROGRESS', 'COMPLETED'];
    if (!validStatus.includes(new_status)) {
        return res.status(400).json({ success: false, error: `O status fornecido "${new_status}" é inválido. Status permitidos: ${validStatus.join(', ')}.` });
    }

    // 2. Checagem de Autorização do Técnico
    if (req.user.role !== 'tech') {
        return res.status(403).json({ success: false, message: 'Apenas técnicos podem atualizar o status de trabalho do ticket.' });
    }

    try {
        // 3. Busca e Checagem 
        const checkResult = await pool.query(
            `SELECT
                t.title,
                t.requested_by AS seller_id,
                t.status,
                tech.name AS tech_name
             FROM tickets t
             JOIN users tech ON tech.id = t.assigned_to
             WHERE t.id = $1 AND t.assigned_to = $2 AND tech.role = $3 AND t.status = 'APPROVED'`,
            [ticketId, userId, 'tech'] 
        );

        if (checkResult.rows.length === 0) {
            return res.status(403).json({ success: false, error: 'Ticket não encontrado, não atribuído a você, ou não foi aprovado pelo Admin.' });
        }

        const { title: ticketTitle, seller_id: sellerId, tech_name: techName } = checkResult.rows[0];

        // 4. Atualiza o status DE TRABALHO do técnico (tech_status)
        const result = await pool.query(
            `UPDATE tickets
             SET tech_status = $1::VARCHAR(50), 
                 last_updated_by = $3,
                 updated_at = now(),
                 completed_at = CASE WHEN $1 = 'COMPLETED' THEN now() ELSE completed_at END
             WHERE id = $2 RETURNING *`,
            [new_status, ticketId, userId]
        );

        const ticket = result.rows[0];

        // 5. [Lógica de Notificação FCM do Código 2 - Mantida]
        console.log(`Notificação FCM (simulada) para Admin/Vendedor sobre status ${new_status}.`);

        // 6. Retorno de sucesso
        res.status(200).json({
            success: true,
            message: `Status de trabalho do Ticket ID ${ticketId} atualizado para ${new_status} por ${techName}.`,
            ticket: ticket
        });

    } catch (err) {
        console.error('Erro em PUT /tickets/:id/tech-status:', err);
        res.status(500).json({ success: false, error: 'Erro ao atualizar status do ticket.', details: err.message });
    }
});


module.exports = router;
