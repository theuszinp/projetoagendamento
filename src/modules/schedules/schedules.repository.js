const pool = require('../../../db');

async function withTransaction(work) {
    const client = await pool.connect();

    try {
        await client.query('BEGIN');
        const result = await work(client);
        await client.query('COMMIT');
        return result;
    } catch (error) {
        await client.query('ROLLBACK');
        throw error;
    } finally {
        client.release();
    }
}

async function findCustomerByNormalizedIdentifier(db, normalizedIdentifier) {
    const result = await db.query(
        `SELECT id, identifier
         FROM customers
         WHERE REPLACE(REPLACE(REPLACE(REPLACE(identifier, '.', ''), '-', ''), '/', ''), ' ', '') = $1`,
        [normalizedIdentifier]
    );

    return result.rows[0] || null;
}

async function findCustomerById(db, customerId) {
    const result = await db.query(
        'SELECT id, identifier FROM customers WHERE id = $1',
        [customerId]
    );

    return result.rows[0] || null;
}

async function createCustomer(db, { name, address, identifier, phoneNumber }) {
    const result = await db.query(
        `INSERT INTO customers (name, address, identifier, phone_number)
         VALUES ($1, $2, $3, $4)
         RETURNING id, name, address, identifier, phone_number`,
        [name, address, identifier, phoneNumber]
    );

    return result.rows[0];
}

async function updateCustomer(db, { customerId, name, address, phoneNumber }) {
    const result = await db.query(
        `UPDATE customers
         SET name = $1, address = $2, phone_number = $3
         WHERE id = $4
         RETURNING id, name, address, identifier, phone_number`,
        [name, address, phoneNumber, customerId]
    );

    return result.rows[0] || null;
}

async function createTicket(db, payload) {
    const result = await db.query(
        `INSERT INTO tickets
         (title, description, priority, customer_id, customer_name, customer_address, requested_by, assigned_to, status, tech_status)
         VALUES ($1, $2, $3, $4, $5, $6, $7, NULL, 'PENDING', NULL)
         RETURNING *`,
        [
            payload.title,
            payload.description,
            payload.priority,
            payload.customerId,
            payload.customerName,
            payload.address,
            payload.requestedBy,
        ]
    );

    return result.rows[0];
}

async function listAllTickets() {
    const result = await pool.query(
        `SELECT
            t.*,
            u.name AS assigned_to_name
         FROM tickets t
         LEFT JOIN users u ON t.assigned_to = u.id
         ORDER BY t.created_at DESC`
    );

    return result.rows;
}

async function listTicketsByRequester(requestedBy) {
    const result = await pool.query(
        `SELECT
            t.*,
            u.name AS assigned_to_name
         FROM tickets t
         LEFT JOIN users u ON t.assigned_to = u.id
         WHERE t.requested_by = $1
         ORDER BY t.created_at DESC`,
        [requestedBy]
    );

    return result.rows;
}

async function listTicketsByTechnician(technicianId) {
    const result = await pool.query(
        `SELECT
            t.*,
            u.name AS assigned_to_name
         FROM tickets t
         LEFT JOIN users u ON t.assigned_to = u.id
         WHERE t.assigned_to = $1
           AND (t.status = 'APPROVED' OR t.tech_status IN ('IN_PROGRESS', 'COMPLETED'))
         ORDER BY t.created_at DESC`,
        [technicianId]
    );

    return result.rows;
}

async function findTicketById(ticketId) {
    const result = await pool.query(
        `SELECT
            t.*,
            u.name AS assigned_to_name
         FROM tickets t
         LEFT JOIN users u ON t.assigned_to = u.id
         WHERE t.id = $1`,
        [ticketId]
    );

    return result.rows[0] || null;
}

async function findTechnicianById(db, technicianId) {
    const result = await db.query(
        'SELECT id, name, email, fcm_token FROM users WHERE id = $1 AND role = $2',
        [technicianId, 'tech']
    );

    return result.rows[0] || null;
}

async function lockTicketById(db, ticketId) {
    const result = await db.query(
        'SELECT * FROM tickets WHERE id = $1 FOR UPDATE',
        [ticketId]
    );

    return result.rows[0] || null;
}

async function approveTicket(db, { ticketId, adminId, technicianId }) {
    const result = await db.query(
        `UPDATE tickets
         SET status = 'APPROVED',
             approved_by = $1,
             approved_at = NOW(),
             assigned_to = $2,
             tech_status = NULL,
             updated_at = NOW(),
             last_updated_by = $1
         WHERE id = $3
         RETURNING *`,
        [adminId, technicianId, ticketId]
    );

    return result.rows[0] || null;
}

async function rejectTicket(db, { ticketId, adminId }) {
    const result = await db.query(
        `UPDATE tickets
         SET status = 'REJECTED',
             approved_by = $1,
             approved_at = NOW(),
             assigned_to = NULL,
             tech_status = NULL,
             updated_at = NOW(),
             last_updated_by = $1
         WHERE id = $2
         RETURNING *`,
        [adminId, ticketId]
    );

    return result.rows[0] || null;
}

async function updateTechStatus(db, { ticketId, userId, newStatus }) {
    const result = await db.query(
        `UPDATE tickets
         SET tech_status = $1::VARCHAR(50),
             last_updated_by = $3,
             updated_at = NOW(),
             started_at = CASE WHEN $1 = 'IN_PROGRESS' THEN COALESCE(started_at, NOW()) ELSE started_at END,
             completed_at = CASE WHEN $1 = 'COMPLETED' THEN COALESCE(completed_at, NOW()) ELSE completed_at END
         WHERE id = $2
         RETURNING *`,
        [newStatus, ticketId, userId]
    );

    return result.rows[0] || null;
}

async function insertStatusHistory(db, payload) {
    await db.query(
        `INSERT INTO ticket_status_history
         (ticket_id, previous_status, next_status, actor_id, actor_role, note)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [
            payload.ticketId,
            payload.previousStatus,
            payload.nextStatus,
            payload.actorId,
            payload.actorRole,
            payload.note || null,
        ]
    );
}

async function listStatusHistory(ticketId) {
    const result = await pool.query(
        `SELECT
            h.*,
            u.name AS actor_name
         FROM ticket_status_history h
         LEFT JOIN users u ON u.id = h.actor_id
         WHERE h.ticket_id = $1
         ORDER BY h.created_at ASC`,
        [ticketId]
    );

    return result.rows;
}

async function insertTicketNote(db, payload) {
    const result = await db.query(
        `INSERT INTO ticket_notes
         (ticket_id, author_id, author_role, note_type, content)
         VALUES ($1, $2, $3, $4, $5)
         RETURNING *`,
        [
            payload.ticketId,
            payload.authorId,
            payload.authorRole,
            payload.noteType,
            payload.content,
        ]
    );

    return result.rows[0];
}

async function insertTicketAttachment(db, payload) {
    const result = await db.query(
        `INSERT INTO ticket_attachments
         (ticket_id, url, storage_path, file_name, content_type, uploaded_by)
         VALUES ($1, $2, $3, $4, $5, $6)
         RETURNING *`,
        [
            payload.ticketId,
            payload.url,
            payload.storagePath,
            payload.fileName,
            payload.contentType,
            payload.uploadedBy,
        ]
    );

    return result.rows[0];
}

async function listTicketNotes(ticketId) {
    const result = await pool.query(
        `SELECT
            n.*,
            u.name AS author_name
         FROM ticket_notes n
         LEFT JOIN users u ON u.id = n.author_id
         WHERE n.ticket_id = $1
         ORDER BY n.created_at ASC`,
        [ticketId]
    );

    return result.rows;
}

async function listTicketAttachments(ticketId) {
    const result = await pool.query(
        `SELECT
            a.*,
            u.name AS uploaded_by_name
         FROM ticket_attachments a
         LEFT JOIN users u ON u.id = a.uploaded_by
         WHERE a.ticket_id = $1
         ORDER BY a.created_at ASC`,
        [ticketId]
    );

    return result.rows;
}

async function listNotificationRecipientsByIds(userIds) {
    const normalizedIds = [...new Set(userIds.filter(Boolean).map(Number))];
    if (normalizedIds.length === 0) {
        return [];
    }

    const result = await pool.query(
        `SELECT id, name, email, role, fcm_token
         FROM users
         WHERE id = ANY($1::int[])`,
        [normalizedIds]
    );

    return result.rows;
}

module.exports = {
    withTransaction,
    findCustomerByNormalizedIdentifier,
    findCustomerById,
    createCustomer,
    updateCustomer,
    createTicket,
    listAllTickets,
    listTicketsByRequester,
    listTicketsByTechnician,
    findTicketById,
    findTechnicianById,
    lockTicketById,
    approveTicket,
    rejectTicket,
    updateTechStatus,
    insertStatusHistory,
    listStatusHistory,
    insertTicketNote,
    insertTicketAttachment,
    listTicketNotes,
    listTicketAttachments,
    listNotificationRecipientsByIds,
};
