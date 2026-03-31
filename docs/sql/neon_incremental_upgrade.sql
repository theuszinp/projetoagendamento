BEGIN;

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    phone VARCHAR(30),
    email VARCHAR(150) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(30) NOT NULL,
    approved BOOLEAN NOT NULL DEFAULT FALSE,
    fcm_token TEXT,
    blocked_at TIMESTAMP NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

ALTER TABLE users ADD COLUMN IF NOT EXISTS phone VARCHAR(30);
ALTER TABLE users ADD COLUMN IF NOT EXISTS password_hash VARCHAR(255);
ALTER TABLE users ADD COLUMN IF NOT EXISTS approved BOOLEAN DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS fcm_token TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS blocked_at TIMESTAMP NULL;
ALTER TABLE users ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT NOW();
ALTER TABLE users ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT NOW();

UPDATE users
SET approved = FALSE
WHERE approved IS NULL;

CREATE TABLE IF NOT EXISTS trackers (
    id SERIAL PRIMARY KEY,
    imei VARCHAR(50) UNIQUE,
    alias VARCHAR(150),
    last_seen TIMESTAMP,
    status VARCHAR(30),
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS customers (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    address TEXT NOT NULL,
    identifier VARCHAR(50) UNIQUE NOT NULL
);

ALTER TABLE customers ADD COLUMN IF NOT EXISTS phone_number VARCHAR(30);
ALTER TABLE customers ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT NOW();
ALTER TABLE customers ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT NOW();

CREATE TABLE IF NOT EXISTS tickets (
    id SERIAL PRIMARY KEY
);

ALTER TABLE tickets ADD COLUMN IF NOT EXISTS tracker_id INTEGER;
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS customer_id INTEGER;
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS title VARCHAR(255);
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS customer_name VARCHAR(150);
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS customer_address TEXT;
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS requested_by INTEGER;
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS assigned_to INTEGER;
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS approved_by INTEGER;
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS last_updated_by INTEGER;
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS status VARCHAR(30) DEFAULT 'PENDING';
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS tech_status VARCHAR(50);
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS priority VARCHAR(20) DEFAULT 'MEDIUM';
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS approved BOOLEAN DEFAULT FALSE;
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS approved_at TIMESTAMP;
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS started_at TIMESTAMP;
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS completed_at TIMESTAMP;
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT NOW();
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT NOW();

UPDATE customers
SET phone_number = 'Não informado'
WHERE phone_number IS NULL;

UPDATE tickets
SET title = 'Serviço sem título'
WHERE title IS NULL OR BTRIM(title) = '';

UPDATE tickets
SET description = 'Sem descrição informada.'
WHERE description IS NULL OR BTRIM(description) = '';

UPDATE tickets
SET customer_name = 'Cliente não informado'
WHERE customer_name IS NULL OR BTRIM(customer_name) = '';

UPDATE tickets
SET customer_address = 'Endereço não informado'
WHERE customer_address IS NULL OR BTRIM(customer_address) = '';

UPDATE tickets
SET tech_status = 'IN_PROGRESS'
WHERE LOWER(COALESCE(status, '')) = 'in_progress'
  AND tech_status IS NULL;

UPDATE tickets
SET tech_status = 'COMPLETED'
WHERE LOWER(COALESCE(status, '')) = 'done'
  AND tech_status IS NULL;

UPDATE tickets
SET status = 'PENDING'
WHERE status IS NULL
   OR LOWER(status) IN ('open', 'pending');

UPDATE tickets
SET status = 'APPROVED'
WHERE LOWER(status) IN ('approved', 'in_progress', 'done');

UPDATE tickets
SET status = 'REJECTED'
WHERE LOWER(status) IN ('cancelled', 'rejected');

UPDATE tickets
SET priority = CASE
    WHEN LOWER(COALESCE(priority, '')) IN ('low', 'baixa') THEN 'LOW'
    WHEN LOWER(COALESCE(priority, '')) IN ('high', 'alta') THEN 'HIGH'
    ELSE 'MEDIUM'
END;

UPDATE tickets
SET approved = CASE
    WHEN status = 'APPROVED' THEN TRUE
    ELSE COALESCE(approved, FALSE)
END;

ALTER TABLE tickets ALTER COLUMN title SET NOT NULL;
ALTER TABLE tickets ALTER COLUMN customer_name SET NOT NULL;
ALTER TABLE tickets ALTER COLUMN customer_address SET NOT NULL;
ALTER TABLE tickets ALTER COLUMN description SET NOT NULL;
ALTER TABLE tickets ALTER COLUMN status SET DEFAULT 'PENDING';
ALTER TABLE tickets ALTER COLUMN priority SET DEFAULT 'MEDIUM';

CREATE TABLE IF NOT EXISTS ticket_attachments (
    id SERIAL PRIMARY KEY,
    ticket_id INTEGER NOT NULL,
    url TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

ALTER TABLE ticket_attachments ADD COLUMN IF NOT EXISTS storage_path TEXT;
ALTER TABLE ticket_attachments ADD COLUMN IF NOT EXISTS file_name VARCHAR(255);
ALTER TABLE ticket_attachments ADD COLUMN IF NOT EXISTS content_type VARCHAR(100);
ALTER TABLE ticket_attachments ADD COLUMN IF NOT EXISTS uploaded_by INTEGER;

CREATE TABLE IF NOT EXISTS ticket_status_history (
    id SERIAL PRIMARY KEY,
    ticket_id INTEGER NOT NULL,
    previous_status VARCHAR(50) NULL,
    next_status VARCHAR(50) NOT NULL,
    actor_id INTEGER NULL,
    actor_role VARCHAR(50) NULL,
    note TEXT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS ticket_notes (
    id SERIAL PRIMARY KEY,
    ticket_id INTEGER NOT NULL,
    author_id INTEGER NULL,
    author_role VARCHAR(50) NULL,
    note_type VARCHAR(50) NOT NULL DEFAULT 'internal',
    content TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'fk_tickets_tracker_id'
    ) THEN
        ALTER TABLE tickets
        ADD CONSTRAINT fk_tickets_tracker_id
        FOREIGN KEY (tracker_id) REFERENCES trackers(id) ON DELETE SET NULL;
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'fk_tickets_customer_id'
    ) THEN
        ALTER TABLE tickets
        ADD CONSTRAINT fk_tickets_customer_id
        FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE SET NULL;
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'fk_tickets_requested_by'
    ) THEN
        ALTER TABLE tickets
        ADD CONSTRAINT fk_tickets_requested_by
        FOREIGN KEY (requested_by) REFERENCES users(id) ON DELETE RESTRICT;
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'fk_tickets_assigned_to'
    ) THEN
        ALTER TABLE tickets
        ADD CONSTRAINT fk_tickets_assigned_to
        FOREIGN KEY (assigned_to) REFERENCES users(id) ON DELETE SET NULL;
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'fk_tickets_approved_by'
    ) THEN
        ALTER TABLE tickets
        ADD CONSTRAINT fk_tickets_approved_by
        FOREIGN KEY (approved_by) REFERENCES users(id) ON DELETE SET NULL;
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'fk_tickets_last_updated_by'
    ) THEN
        ALTER TABLE tickets
        ADD CONSTRAINT fk_tickets_last_updated_by
        FOREIGN KEY (last_updated_by) REFERENCES users(id) ON DELETE SET NULL;
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'fk_ticket_attachments_ticket_id'
    ) THEN
        ALTER TABLE ticket_attachments
        ADD CONSTRAINT fk_ticket_attachments_ticket_id
        FOREIGN KEY (ticket_id) REFERENCES tickets(id) ON DELETE CASCADE;
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'fk_ticket_attachments_uploaded_by'
    ) THEN
        ALTER TABLE ticket_attachments
        ADD CONSTRAINT fk_ticket_attachments_uploaded_by
        FOREIGN KEY (uploaded_by) REFERENCES users(id) ON DELETE SET NULL;
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'fk_ticket_status_history_ticket_id'
    ) THEN
        ALTER TABLE ticket_status_history
        ADD CONSTRAINT fk_ticket_status_history_ticket_id
        FOREIGN KEY (ticket_id) REFERENCES tickets(id) ON DELETE CASCADE;
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'fk_ticket_status_history_actor_id'
    ) THEN
        ALTER TABLE ticket_status_history
        ADD CONSTRAINT fk_ticket_status_history_actor_id
        FOREIGN KEY (actor_id) REFERENCES users(id) ON DELETE SET NULL;
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'fk_ticket_notes_ticket_id'
    ) THEN
        ALTER TABLE ticket_notes
        ADD CONSTRAINT fk_ticket_notes_ticket_id
        FOREIGN KEY (ticket_id) REFERENCES tickets(id) ON DELETE CASCADE;
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'fk_ticket_notes_author_id'
    ) THEN
        ALTER TABLE ticket_notes
        ADD CONSTRAINT fk_ticket_notes_author_id
        FOREIGN KEY (author_id) REFERENCES users(id) ON DELETE SET NULL;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_customers_identifier ON customers(identifier);
CREATE INDEX IF NOT EXISTS idx_tickets_requested_by ON tickets(requested_by);
CREATE INDEX IF NOT EXISTS idx_tickets_assigned_to ON tickets(assigned_to);
CREATE INDEX IF NOT EXISTS idx_tickets_status ON tickets(status);
CREATE INDEX IF NOT EXISTS idx_tickets_tech_status ON tickets(tech_status);
CREATE INDEX IF NOT EXISTS idx_tickets_customer_id ON tickets(customer_id);
CREATE INDEX IF NOT EXISTS idx_ticket_attachments_ticket_id ON ticket_attachments(ticket_id);
CREATE INDEX IF NOT EXISTS idx_ticket_attachments_uploaded_by ON ticket_attachments(uploaded_by);
CREATE INDEX IF NOT EXISTS idx_ticket_status_history_ticket_id ON ticket_status_history(ticket_id);
CREATE INDEX IF NOT EXISTS idx_ticket_notes_ticket_id ON ticket_notes(ticket_id);

DROP TRIGGER IF EXISTS trg_users_updated_at ON users;
CREATE TRIGGER trg_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_customers_updated_at ON customers;
CREATE TRIGGER trg_customers_updated_at
BEFORE UPDATE ON customers
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_tickets_updated_at ON tickets;
CREATE TRIGGER trg_tickets_updated_at
BEFORE UPDATE ON tickets
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

COMMIT;
