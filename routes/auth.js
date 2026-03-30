const express = require('express');
const router = express.Router();
const pool = require('../db');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');


// =====================================================================
// 🔐 LOGIN (com aprovação + bcrypt + JWT)
// =====================================================================
router.post('/login', async (req, res) => {
    try {
        const { email, senha } = req.body;

        if (!email || !senha) {
            return res.status(400).json({
                success: false,
                message: 'Email e senha são obrigatórios.'
            });
        }

        const result = await pool.query(
            'SELECT * FROM users WHERE email = $1',
            [email]
        );

        const user = result.rows[0];

        if (!user) {
            return res.status(401).json({
                success: false,
                message: 'Credenciais inválidas.'
            });
        }

        // 🔥 BLOQUEIO DE USUÁRIO NÃO APROVADO
        if (!user.approved) {
            return res.status(403).json({
                success: false,
                message: 'Aguardando aprovação do administrador.'
            });
        }

        // 🔐 Verifica senha
        const isMatch = await bcrypt.compare(senha, user.password_hash);

        if (!isMatch) {
            return res.status(401).json({
                success: false,
                message: 'Credenciais inválidas.'
            });
        }

        // 🔑 Gera token JWT
        const token = jwt.sign(
            {
                id: user.id,
                role: user.role
            },
            process.env.JWT_SECRET,
            { expiresIn: '8h' }
        );

        return res.json({
            success: true,
            message: 'Login realizado com sucesso.',
            user: {
                id: user.id,
                name: user.name,
                role: user.role
            },
            token
        });

    } catch (err) {
        console.error('Erro no login:', err);
        return res.status(500).json({
            success: false,
            message: 'Erro interno no login.'
        });
    }
});


// =====================================================================
// 🧾 CADASTRO DE USUÁRIO (fica pendente de aprovação)
// =====================================================================
router.post('/users', async (req, res) => {
    try {
        const { name, email, senha, role } = req.body;

        if (!name || !email || !senha || !role) {
            return res.status(400).json({
                success: false,
                message: 'Campos obrigatórios ausentes.'
            });
        }

        // Verifica se já existe
        const existing = await pool.query(
            'SELECT id FROM users WHERE email = $1',
            [email]
        );

        if (existing.rows.length > 0) {
            return res.status(400).json({
                success: false,
                message: 'Email já cadastrado.'
            });
        }

        // 🔐 Criptografa senha
        const password_hash = await bcrypt.hash(senha, 10);

        // 🔥 Usuário já nasce NÃO aprovado
        await pool.query(
            `INSERT INTO users (name, email, password_hash, role, approved)
             VALUES ($1, $2, $3, $4, false)`,
            [name, email, password_hash, role]
        );

        return res.status(201).json({
            success: true,
            message: 'Cadastro realizado. Aguarde aprovação do administrador.'
        });

    } catch (err) {
        console.error('Erro ao criar usuário:', err);
        return res.status(500).json({
            success: false,
            message: 'Erro ao criar usuário.'
        });
    }
});


// =====================================================================
// 🛠️ APROVAR USUÁRIO (ADMIN)
// =====================================================================
router.put('/approve-user/:id', async (req, res) => {
    try {
        const { id } = req.params;

        await pool.query(
            'UPDATE users SET approved = true WHERE id = $1',
            [id]
        );

        return res.json({
            success: true,
            message: 'Usuário aprovado com sucesso.'
        });

    } catch (err) {
        console.error('Erro ao aprovar usuário:', err);
        return res.status(500).json({
            success: false,
            message: 'Erro ao aprovar usuário.'
        });
    }
});


// =====================================================================
// 📋 LISTAR USUÁRIOS PENDENTES (OPCIONAL)
// =====================================================================
router.get('/pending-users', async (req, res) => {
    try {
        const result = await pool.query(
            'SELECT id, name, email FROM users WHERE approved = false'
        );

        return res.json({
            success: true,
            users: result.rows
        });

    } catch (err) {
        console.error('Erro ao buscar usuários pendentes:', err);
        return res.status(500).json({
            success: false,
            message: 'Erro ao buscar usuários.'
        });
    }
});

module.exports = router;