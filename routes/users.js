const express = require('express');
const router = express.Router();
const pool = require('../db');
const bcrypt = require('bcrypt');
const { authMiddleware, roleMiddleware } = require('../server'); // Importa middlewares

// 🆕 ROTA: ATUALIZAÇÃO DE SENHA (com bcrypt)
router.put('/:id/password', authMiddleware, async (req, res) => {
    // ... (coloque aqui a lógica completa da sua rota /users/:id/password) ...
    const userId = parseInt(req.params.id, 10);
    const { old_senha, new_senha } = req.body;

    if (req.user.id != userId && req.user.role !== 'admin') {
        return res.status(403).json({ success: false, message: 'Acesso negado. Você só pode mudar sua própria senha.' });
    }

    if (!new_senha || isNaN(userId)) {
        return res.status(400).json({ success: false, message: 'Nova senha ou ID de usuário inválido é obrigatório.' });
    }

    try {
        const result = await pool.query('SELECT password_hash FROM users WHERE id = $1', [userId]);
        const user = result.rows[0];

        if (!user) return res.status(404).json({ success: false, message: 'Usuário não encontrado.' });

        if (old_senha) {
            const isMatch = await bcrypt.compare(old_senha, user.password_hash);
            if (!isMatch) return res.status(401).json({ success: false, message: 'Senha antiga incorreta.' });
        } else if (req.user.role !== 'admin') {
            return res.status(400).json({ success: false, message: 'Senha antiga é obrigatória para não-administradores.' });
        }

        const new_password_hash = await bcrypt.hash(new_senha, 10);

        await pool.query('UPDATE users SET password_hash = $1 WHERE id = $2', [
            new_password_hash,
            userId,
        ]);

        res.json({ success: true, message: 'Senha atualizada com sucesso. Por favor, faça login novamente.' });
    } catch (err) {
        console.error('Erro ao atualizar senha:', err);
        res.status(500).json({ success: false, message: 'Erro interno ao atualizar senha.' });
    }
});

// 2️⃣ Rota: LISTAR TODOS OS USUÁRIOS (APENAS ADMIN)
router.get('/', authMiddleware, roleMiddleware('admin'), async (req, res) => {
    // ... (coloque aqui a lógica completa da sua rota GET /users) ...
    try {
        const result = await pool.query(
            'SELECT id, name, email, role FROM users ORDER BY name ASC'
        );
        res.json({ success: true, users: result.rows });
    } catch (err) {
        console.error('Erro em GET /users:', err);
        res.status(500).json({ success: false, error: 'Erro ao listar usuários.' });
    }
});

// 🆕 Rota 2.1: LISTAR SOMENTE TÉCNICOS
router.get('/technicians', authMiddleware, async (req, res) => {
    // ... (coloque aqui a lógica completa da sua rota GET /technicians) ...
    if (req.user.role !== 'admin' && req.user.role !== 'seller') {
        return res.status(403).json({ success: false, message: 'Acesso negado.' });
    }

    try {
        const result = await pool.query(
            "SELECT id, name FROM users WHERE role = 'tech' ORDER BY name ASC"
        );
        res.json({ success: true, technicians: result.rows });
    } catch (err) {
        console.error('Erro em GET /technicians:', err);
        res.status(500).json({ success: false, error: 'Erro ao listar técnicos.' });
    }
});

module.exports = router;