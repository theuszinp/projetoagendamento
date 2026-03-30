const pool = require('../../../db');

async function findUserPasswordHashById(userId) {
    const result = await pool.query(
        'SELECT id, password_hash FROM users WHERE id = $1',
        [userId]
    );

    return result.rows[0] || null;
}

async function updatePasswordHash(userId, passwordHash) {
    await pool.query(
        'UPDATE users SET password_hash = $1 WHERE id = $2',
        [passwordHash, userId]
    );
}

async function listUsers() {
    const result = await pool.query(
        'SELECT id, name, email, role, approved FROM users ORDER BY name ASC'
    );
    return result.rows;
}

async function listTechnicians() {
    const result = await pool.query(
        "SELECT id, name, email, role, approved FROM users WHERE role = 'tech' ORDER BY name ASC"
    );
    return result.rows;
}

module.exports = {
    findUserPasswordHashById,
    updatePasswordHash,
    listUsers,
    listTechnicians,
};
