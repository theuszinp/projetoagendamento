const express = require('express');
const router = express.Router();
const pool = require('../db');
const { authMiddleware } = require('../server'); // Importa middlewares

// 5️⃣ Rota: BUSCA DE CLIENTE (POR IDENTIFIER - CPF/CNPJ)
router.get('/search', authMiddleware, async (req, res) => {
    // ... (coloque aqui a lógica completa da sua rota GET /clients/search) ...
    if (req.user.role !== 'admin' && req.user.role !== 'seller') {
        return res.status(403).json({ success: false, message: 'Acesso negado.' });
    }

    const { identifier } = req.query;

    if (!identifier) {
        return res.status(400).json({ success: false, error: 'O identificador (CPF/CNPJ) do cliente é obrigatório.' });
    }

    try {
        const clientResult = await pool.query(
            'SELECT id, name, address, identifier, phone_number FROM customers WHERE identifier = $1',
            [identifier]
        );
        const client = clientResult.rows[0];

        if (!client) {
            return res.status(404).json({ success: false, error: 'Cliente não encontrado.' });
        }

        res.json({
            success: true,
            id: client.id,
            name: client.name,
            address: client.address,
            phoneNumber: client.phone_number
        });

    } catch (err) {
        console.error('Erro em GET /clients/search:', err);
        res.status(500).json({ success: false, error: 'Erro interno do servidor ao buscar cliente.', details: err.message });
    }
});

module.exports = router;