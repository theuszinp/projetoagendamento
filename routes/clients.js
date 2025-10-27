const express = require('express');
const router = express.Router();
const pool = require('../db');
const { authMiddleware } = require('../server'); // Importa o middleware de autenticação

// 🔍 5️⃣ Rota: BUSCA DE CLIENTE (POR IDENTIFIER - CPF/CNPJ)
router.get('/search', authMiddleware, async (req, res) => {
    try {
        // ✅ Verifica permissão (apenas admin ou vendedor)
        if (req.user.role !== 'admin' && req.user.role !== 'seller') {
            return res.status(403).json({ success: false, message: 'Acesso negado.' });
        }

        const { identifier } = req.query;

        // ✅ Validação do parâmetro
        if (!identifier || identifier.trim() === '') {
            return res.status(400).json({ success: false, error: 'O identificador (CPF/CNPJ) do cliente é obrigatório.' });
        }

        // ✅ Normaliza CPF/CNPJ (remove pontos, traços, barras, etc.)
        const cleanIdentifier = identifier.replace(/\D/g, '');

        // ✅ Busca o cliente no banco
        const clientResult = await pool.query(
            `SELECT id, name, address, identifier, phone_number
             FROM customers
             WHERE REPLACE(REPLACE(REPLACE(REPLACE(identifier, '.', ''), '-', ''), '/', ''), ' ', '') = $1`,
            [cleanIdentifier]
        );

        // ✅ Se não encontrou cliente
        if (clientResult.rows.length === 0) {
            return res.status(404).json({ success: false, error: 'Cliente não encontrado.' });
        }

        // ✅ Monta o objeto de resposta
        const client = clientResult.rows[0];

        return res.status(200).json({
            success: true,
            client: {
                id: client.id,
                name: client.name,
                address: client.address,
                identifier: client.identifier,
                phoneNumber: client.phone_number
            }
        });

    } catch (err) {
        console.error('Erro em GET /clients/search:', err);
        return res.status(500).json({
            success: false,
            error: 'Erro interno do servidor ao buscar cliente.',
            details: err.message
        });
    }
});

module.exports = router;
