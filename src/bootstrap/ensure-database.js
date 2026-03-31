const pool = require('../../db');

async function ensureDatabase() {
    console.log('Verificando banco de dados...');

    await pool.query(`
        ALTER TABLE tickets
        ADD COLUMN IF NOT EXISTS tech_status VARCHAR(50) DEFAULT NULL;
    `);

    await pool.query(`
        ALTER TABLE tickets
        ADD COLUMN IF NOT EXISTS approved_by INTEGER NULL;
    `);

    await pool.query(`
        ALTER TABLE tickets
        ADD COLUMN IF NOT EXISTS approved_at TIMESTAMP NULL;
    `);

    await pool.query(`
        ALTER TABLE tickets
        ADD COLUMN IF NOT EXISTS started_at TIMESTAMP NULL;
    `);

    await pool.query(`
        ALTER TABLE tickets
        ADD COLUMN IF NOT EXISTS completed_at TIMESTAMP NULL;
    `);

    await pool.query(`
        ALTER TABLE tickets
        ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP NULL;
    `);

    await pool.query(`
        ALTER TABLE tickets
        ADD COLUMN IF NOT EXISTS last_updated_by INTEGER NULL;
    `);

    await pool.query(`
        CREATE TABLE IF NOT EXISTS ticket_status_history (
            id SERIAL PRIMARY KEY,
            ticket_id INTEGER NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
            previous_status VARCHAR(50) NULL,
            next_status VARCHAR(50) NOT NULL,
            actor_id INTEGER NULL REFERENCES users(id) ON DELETE SET NULL,
            actor_role VARCHAR(50) NULL,
            note TEXT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT NOW()
        );
    `);

    await pool.query(`
        CREATE TABLE IF NOT EXISTS ticket_notes (
            id SERIAL PRIMARY KEY,
            ticket_id INTEGER NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
            author_id INTEGER NULL REFERENCES users(id) ON DELETE SET NULL,
            author_role VARCHAR(50) NULL,
            note_type VARCHAR(50) NOT NULL,
            content TEXT NOT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT NOW()
        );
    `);

    await pool.query(`
        CREATE TABLE IF NOT EXISTS ticket_attachments (
            id SERIAL PRIMARY KEY,
            ticket_id INTEGER NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
            url TEXT NOT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT NOW()
        );
    `);

    await pool.query(`
        ALTER TABLE ticket_attachments
        ADD COLUMN IF NOT EXISTS storage_path TEXT NULL;
    `);

    await pool.query(`
        ALTER TABLE ticket_attachments
        ADD COLUMN IF NOT EXISTS file_name VARCHAR(255) NULL;
    `);

    await pool.query(`
        ALTER TABLE ticket_attachments
        ADD COLUMN IF NOT EXISTS content_type VARCHAR(100) NULL;
    `);

    await pool.query(`
        ALTER TABLE ticket_attachments
        ADD COLUMN IF NOT EXISTS uploaded_by INTEGER NULL REFERENCES users(id) ON DELETE SET NULL;
    `);

    const indexes = [
        'CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);',
        'CREATE INDEX IF NOT EXISTS idx_tickets_assigned_to ON tickets(assigned_to);',
        'CREATE INDEX IF NOT EXISTS idx_tickets_requested_by ON tickets(requested_by);',
        'CREATE INDEX IF NOT EXISTS idx_customers_identifier ON customers(identifier);',
        'CREATE INDEX IF NOT EXISTS idx_tickets_tech_status ON tickets(tech_status);',
        'CREATE INDEX IF NOT EXISTS idx_ticket_status_history_ticket_id ON ticket_status_history(ticket_id);',
        'CREATE INDEX IF NOT EXISTS idx_ticket_notes_ticket_id ON ticket_notes(ticket_id);',
        'CREATE INDEX IF NOT EXISTS idx_ticket_attachments_ticket_id ON ticket_attachments(ticket_id);',
        'CREATE INDEX IF NOT EXISTS idx_ticket_attachments_uploaded_by ON ticket_attachments(uploaded_by);',
    ];

    for (const statement of indexes) {
        await pool.query(statement);
    }

    console.log('Banco verificado com sucesso.');
}

module.exports = { ensureDatabase };
