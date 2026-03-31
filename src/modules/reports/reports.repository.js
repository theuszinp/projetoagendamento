const pool = require('../../../db');

async function listTechSummary({ from, to }) {
    const result = await pool.query(
        `
        WITH completed AS (
            SELECT
                t.id,
                t.assigned_to AS tech_id,
                CASE
                    WHEN t.started_at IS NOT NULL AND t.completed_at IS NOT NULL
                        THEN EXTRACT(EPOCH FROM (t.completed_at - t.started_at)) / 60.0
                    ELSE NULL
                END AS duration_min
            FROM tickets t
            WHERE t.tech_status = 'COMPLETED'
              AND t.completed_at IS NOT NULL
              AND t.completed_at >= $1::timestamp
              AND t.completed_at < ($2::timestamp + interval '1 day')
        )
        SELECT
            u.id AS tech_id,
            u.name AS tech_name,
            COUNT(c.id) AS services_completed,
            ROUND(COALESCE(SUM(c.duration_min), 0)::numeric, 2) AS total_minutes,
            ROUND(COALESCE(AVG(c.duration_min), 0)::numeric, 2) AS avg_minutes,
            ROUND(COALESCE(MIN(c.duration_min), 0)::numeric, 2) AS min_minutes,
            ROUND(COALESCE(MAX(c.duration_min), 0)::numeric, 2) AS max_minutes
        FROM users u
        LEFT JOIN completed c ON c.tech_id = u.id
        WHERE u.role = 'tech'
        GROUP BY u.id, u.name
        ORDER BY services_completed DESC, u.name ASC
        `,
        [from, to]
    );

    return result.rows;
}

async function listCompletedServices({ from, to, search }) {
    const normalizedSearch = (search || '').trim();

    const result = await pool.query(
        `
        SELECT
            t.id AS ticket_id,
            t.title,
            t.customer_name,
            t.customer_address,
            t.priority,
            t.status,
            t.tech_status,
            t.created_at,
            t.started_at,
            t.completed_at,
            t.requested_by AS seller_id,
            seller.name AS seller_name,
            t.assigned_to AS tech_id,
            tech.name AS tech_name,
            COUNT(a.id) AS attachments_count,
            CASE
                WHEN t.started_at IS NOT NULL AND t.completed_at IS NOT NULL
                    THEN ROUND((EXTRACT(EPOCH FROM (t.completed_at - t.started_at)) / 60.0)::numeric, 2)
                ELSE NULL
            END AS duration_min
        FROM tickets t
        LEFT JOIN users seller ON seller.id = t.requested_by
        LEFT JOIN users tech ON tech.id = t.assigned_to
        LEFT JOIN ticket_attachments a ON a.ticket_id = t.id
        WHERE t.tech_status = 'COMPLETED'
          AND t.completed_at IS NOT NULL
          AND t.completed_at >= $1::timestamp
          AND t.completed_at < ($2::timestamp + interval '1 day')
          AND (
                $3::text = ''
                OR COALESCE(t.title, '') ILIKE '%' || $3 || '%'
                OR COALESCE(t.customer_name, '') ILIKE '%' || $3 || '%'
                OR COALESCE(t.customer_address, '') ILIKE '%' || $3 || '%'
                OR COALESCE(seller.name, '') ILIKE '%' || $3 || '%'
                OR COALESCE(tech.name, '') ILIKE '%' || $3 || '%'
              )
        GROUP BY
            t.id,
            seller.name,
            tech.name
        ORDER BY t.completed_at DESC, t.id DESC
        `,
        [from, to, normalizedSearch]
    );

    return result.rows;
}

module.exports = {
    listTechSummary,
    listCompletedServices,
};
