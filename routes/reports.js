
const express = require('express');
const router = express.Router();
const pool = require('../db');
const { authMiddleware, roleMiddleware } = require('../middleware/auth');

// =====================================================================
// 📊 RELATÓRIOS (ADMIN)
// =====================================================================

// GET /reports/tech-summary?from=2026-01-01&to=2026-01-31
// Retorna: total de serviços por técnico, total de minutos, média, etc.
router.get('/tech-summary', authMiddleware, roleMiddleware('admin'), async (req, res) => {
  const { from, to } = req.query;

  // Datas opcionais. Se não vier, pega últimos 30 dias.
  const toDate = to ? new Date(to) : new Date();
  const fromDate = from ? new Date(from) : new Date(toDate.getTime() - 30 * 24 * 60 * 60 * 1000);

  if (isNaN(fromDate.getTime()) || isNaN(toDate.getTime())) {
    return res.status(400).json({ success: false, message: 'Parâmetros from/to inválidos. Use YYYY-MM-DD.' });
  }

  try {
    const result = await pool.query(
      `
      WITH completed AS (
        SELECT
          t.id,
          t.assigned_to AS tech_id,
          t.started_at,
          t.completed_at,
          t.created_at,
          -- duração em minutos (só conta se tiver as duas datas)
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
        ROUND(COALESCE(SUM(c.duration_min),0)::numeric, 2) AS total_minutes,
        ROUND(COALESCE(AVG(c.duration_min),0)::numeric, 2) AS avg_minutes,
        ROUND(COALESCE(MIN(c.duration_min),0)::numeric, 2) AS min_minutes,
        ROUND(COALESCE(MAX(c.duration_min),0)::numeric, 2) AS max_minutes
      FROM users u
      LEFT JOIN completed c ON c.tech_id = u.id
      WHERE u.role = 'tech'
      GROUP BY u.id, u.name
      ORDER BY services_completed DESC, u.name ASC
      `,
      [fromDate.toISOString().slice(0,10), toDate.toISOString().slice(0,10)]
    );

    res.json({
      success: true,
      range: { from: fromDate.toISOString().slice(0,10), to: toDate.toISOString().slice(0,10) },
      rows: result.rows
    });
  } catch (err) {
    console.error('Erro em GET /reports/tech-summary:', err);
    res.status(500).json({ success: false, message: 'Erro ao gerar relatório.', details: err.message });
  }
});

module.exports = router;
