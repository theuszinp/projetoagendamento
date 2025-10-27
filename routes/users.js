const express = require('express');
const router = express.Router();
const pool = require('../db');
const bcrypt = require('bcrypt');
const { authMiddleware, roleMiddleware } = require('../server'); // Importa middlewares

// 🔐 1️⃣ ROTA: ATUALIZAÇÃO DE SENHA (com bcrypt)
router.put('/:id/password', authMiddleware, async (req, res) => {
    const userId = parseInt(req.params.id, 10);
    const { old_senha, new_senha } = req.body;

    // 🧩 Verificações básicas
    if (isNaN(userId)) {
        return res.status(400).json({ success: false, message: 'ID de usuário inválido.' });
    }

    if (!new_senha || new_senha.trim().length < 6) {
        return res.status(400).json({ success: false, message: 'Nova senha é obrigatória e deve ter pelo menos 6 caracteres.' });
    }

    // 🔒 Apenas o próprio usuário ou um admin podem alterar a senha
    if (req.user.id !== userId && req.user.role !== 'admin') {
        return res.status(403).json({ success: false, message: 'Acesso negado. Você só pode mudar sua própria senha.' });
    }

    try {
        // Busca o usuário no banco
        const result = await pool.query('SELECT password_hash FROM users WHERE id = $1', [userId]);
        const user = result.rows[0];

        if (!user) {
            return res.status(404).json({ success: false, message: 'Usuário não encontrado.' });
        }

        // Verifica senha antiga, exceto para admin
        if (req.user.role !== 'admin') {
            if (!old_senha) {
                return res.status(400).json({ success: false, message: 'Senha antiga é obrigatória para não administradores.' });
            }

            const isMatch = await bcrypt.compare(old_senha, user.password_hash);
            if (!isMatch) {
                return res.status(401).json({ success: false, message: 'Senha antiga incorreta.' });
            }
        }

        // Gera novo hash e atualiza
        const new_password_hash = await bcrypt.hash(new_senha.trim(), 10);
        await pool.query('UPDATE users SET password_hash = $1 WHERE id = $2', [new_password_hash, userId]);

        return res.json({ success: true, message: 'Senha atualizada com sucesso. Faça login novamente.' });
    } catch (err) {
        console.error('Erro ao atualizar senha:', err);
        return res.status(500).json({ success: false, message: 'Erro interno ao atualizar senha.', details: err.message });
    }
});

// 👥 2️⃣ ROTA: LISTAR TODOS OS USUÁRIOS (APENAS ADMIN)
router.get('/', authMiddleware, roleMiddleware('admin'), async (req, res) => {
    try {
        const result = await pool.query(
            'SELECT id, name, email, role FROM users ORDER BY name ASC'
        );
        return res.json({ success: true, users: result.rows });
    } catch (err) {
        console.error('Erro em GET /users:', err);
        return res.status(500).json({ success: false, error: 'Erro ao listar usuários.', details: err.message });
    }
});

// 🧰 3️⃣ ROTA: LISTAR SOMENTE TÉCNICOS (admin e vendedor)
router.get('/technicians', authMiddleware, async (req, res) => {
    if (req.user.role !== 'admin' && req.user.role !== 'seller') {
        return res.status(403).json({ success: false, message: 'Acesso negado.' });
    }

    try {
        const result = await pool.query(
            "SELECT id, name FROM users WHERE role = 'tech' ORDER BY name ASC"
        );
        return res.json({ success: true, technicians: result.rows });
    } catch (err) {
        console.error('Erro em GET /technicians:', err);
        return res.status(500).json({ success: false, error: 'Erro ao listar técnicos.', details: err.message });
    }
});

module.exports = router;
