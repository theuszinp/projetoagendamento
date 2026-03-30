const pool = require('../../../db');

async function findByNormalizedIdentifier(normalizedIdentifier) {
    const result = await pool.query(
        `SELECT id, name, address, identifier, phone_number
         FROM customers
         WHERE REPLACE(REPLACE(REPLACE(REPLACE(identifier, '.', ''), '-', ''), '/', ''), ' ', '') = $1`,
        [normalizedIdentifier]
    );

    return result.rows[0] || null;
}

module.exports = {
    findByNormalizedIdentifier,
};
