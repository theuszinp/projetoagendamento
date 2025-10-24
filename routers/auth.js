const express = require('express');
const router = express.Router();
const pool = require('../db');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');

// 🧩 LOGIN (com bcrypt + JWT)
router.post('/login', async (req, res) => {
    try {
        const { email, senha } = req.body;
        // ... (resto da sua lógica de login) ...
        if (!email || !senha)
            return res.status(400).json({ success: false, message: 'Email e senha são obrigatórios.' });

        const result = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
        const user = result.rows[0];

        if (!user) return res.status(401).json({ success: false, message: 'Credenciais inválidas.' });

        const isMatch = await bcrypt.compare(senha, user.password_hash);
        if (!isMatch) return res.status(401).json({ success: false, message: 'Credenciais inválidas.' });

        const token = jwt.sign({ id: user.id, role: user.role }, process.env.JWT_SECRET, {
            expiresIn: '8h',
        });

        res.json({
            success: true,
            user: { id: user.id, name: user.name, role: user.role },
            token,
        });
    } catch (err) {
        console.error('Erro no login:', err);
        res.status(500).json({ success: false, message: 'Erro interno no login.' });
    }
});

// 🧾 ROTA DE CRIAÇÃO DE USUÁRIOS (com bcrypt)
router.post('/users', async (req, res) => {
    try {
        const { name, email, senha, role } = req.body;
        // ... (resto da sua lógica de criação de usuário) ...
        if (!name || !email || !senha || !role)
            return res.status(400).json({ success: false, message: 'Campos obrigatórios ausentes.' });

        const existing = await pool.query('SELECT id FROM users WHERE email = $1', [email]);
        if (existing.rows.length > 0)
            return res.status(400).json({ success: false, message: 'Email já cadastrado.' });

        const password_hash = await bcrypt.hash(senha, 10);
        await pool.query('INSERT INTO users (name, email, password_hash, role) VALUES ($1, $2, $3, $4)', [
            name,
            email,
            password_hash,
            role,
        ]);

        res.status(201).json({ success: true, message: 'Usuário criado com sucesso.' });
    } catch (err) {
        console.error('Erro ao criar usuário:', err);
        res.status(500).json({ success: false, message: 'Erro ao criar usuário.' });
    }
});

module.exports = router;