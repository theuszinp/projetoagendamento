const pool = require('../../../db');

async function findUserByEmail(email) {
    const result = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
    return result.rows[0] || null;
}

async function createUser({ name, email, passwordHash, role }) {
    const result = await pool.query(
        `INSERT INTO users (name, email, password_hash, role, approved)
         VALUES ($1, $2, $3, $4, false)
         RETURNING id, name, email, role, approved`,
        [name, email, passwordHash, role]
    );

    return result.rows[0];
}

async function approveUser(userId) {
    const result = await pool.query(
        `UPDATE users
         SET approved = true
         WHERE id = $1
         RETURNING id, name, email, role, approved`,
        [userId]
    );

    return result.rows[0] || null;
}

async function listPendingUsers() {
    const result = await pool.query(
        'SELECT id, name, email, role, approved FROM users WHERE approved = false ORDER BY name ASC'
    );

    return result.rows;
}

module.exports = {
    findUserByEmail,
    createUser,
    approveUser,
    listPendingUsers,
};
