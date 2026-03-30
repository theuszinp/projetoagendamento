BEGIN;

INSERT INTO users (
    name,
    email,
    password_hash,
    role,
    approved,
    created_at,
    updated_at
)
VALUES
(
    'Matheus Dantas',
    'matheussdantas14@gmail.com',
    '$2b$10$AF2IyFToucxFGcotVDC2IeBANgstTl6Z9/5aeBXYy7Hz9knUZ10me',
    'admin',
    TRUE,
    NOW(),
    NOW()
),
(
    'Matheus Vendedor',
    'matheusvendedor@gmail.com',
    '$2b$10$AF2IyFToucxFGcotVDC2IeBANgstTl6Z9/5aeBXYy7Hz9knUZ10me',
    'seller',
    TRUE,
    NOW(),
    NOW()
),
(
    'Matheus Instalador',
    'matheusinstalador@gmail.com',
    '$2b$10$AF2IyFToucxFGcotVDC2IeBANgstTl6Z9/5aeBXYy7Hz9knUZ10me',
    'tech',
    TRUE,
    NOW(),
    NOW()
)
ON CONFLICT (email) DO UPDATE
SET
    name = EXCLUDED.name,
    password_hash = EXCLUDED.password_hash,
    role = EXCLUDED.role,
    approved = EXCLUDED.approved,
    updated_at = NOW();

COMMIT;
