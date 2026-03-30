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

module.exports = {
    listTechSummary,
};
