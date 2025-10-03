// server.js (VERSÃO FINAL COM ROTA DE LOGIN)
// =====================================================================

// 🚨 1. CARREGAR VARIÁVEIS DE AMBIENTE (DEVE SER O PRIMEIRO!)
require('dotenv').config(); 

// 2. IMPORTAR LIBS
const express = require('express');
const bodyParser = require('body-parser');

// 3. IMPORTAR MÓDULOS (QUE AGORA CONSEGUEM LER O .env)
// Certifique-se de que db.js e firebase.js NÃO tenham dotenv duplicado!
const pool = require('./db');
const adminFirebase = require('./firebase'); 

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware para processar JSON nas requisições
app.use(bodyParser.json());

// ===============================================
// 4️⃣ Rota: Login de Usuário (NOVA ROTA ADICIONADA)
// ===============================================
app.post('/login', async (req, res) => {
    const { email, senha } = req.body;

    if (!email || !senha) {
        return res.status(400).json({ error: 'Email e senha são obrigatórios.' });
    }

    try {
        // 1. Buscar usuário pelo email na tabela 'users'
        const userResult = await pool.query(
            'SELECT id, name, email, password_hash, role FROM users WHERE email = $1', 
            [email]
        );
        const user = userResult.rows[0];

        if (!user) {
            // Não encontrou o usuário: credenciais inválidas (para segurança)
            return res.status(401).json({ error: 'Credenciais inválidas.' });
        }

        // 2. [!!! PONTO CRÍTICO !!!] Comparar a senha
        // *** CONFIGURADO PARA TESTE DE TEXTO PURO ***
        // Se a senha for HASH (bcrypt), mude a linha abaixo para usar 'await bcrypt.compare(...)'.
        const isMatch = senha === user.password_hash; 
        
        if (!isMatch) {
            return res.status(401).json({ error: 'Credenciais inválidas.' });
        }

        // 3. Sucesso: Retorna os dados do usuário para o Flutter
        res.json({
            id: user.id,
            name: user.name,
            email: user.email,
            role: user.role
        });

    } catch (err) {
        console.error('Erro em POST /login:', err);
        // Garante que o Flutter receba um JSON de erro em vez de HTML
        res.status(500).json({ error: 'Erro interno do servidor ao tentar login.', details: err.message });
    }
});


// ===============================================
// 5️⃣ Rota: Vendedora cria ticket
// ===============================================
app.post('/tickets', async (req, res) => {
  const { tracker_id, customer_name, customer_address, description, requested_by } = req.body;

  try {
    const result = await pool.query(
      `INSERT INTO tickets 
      (tracker_id, customer_name, customer_address, description, requested_by) 
      VALUES ($1, $2, $3, $4, $5) RETURNING *`,
      [tracker_id, customer_name, customer_address, description, requested_by]
    );

    res.status(201).json({ ticket: result.rows[0] });
  } catch (err) {
    console.error('Erro em POST /tickets:', err);
    res.status(500).json({ error: 'Erro ao criar ticket', details: err.message });
  }
});


// ===============================================
// 6️⃣ Rota: Administrativo aprova ticket + Notificação FCM
// ===============================================
app.put('/tickets/:id/approve', async (req, res) => {
  const ticketId = req.params.id;
  const { admin_id, assigned_to } = req.body; 

  const client = await pool.connect(); 

  try {
    await client.query('BEGIN');

    // 1. Atualiza o ticket
    const update = await client.query(
      `UPDATE tickets 
       SET approved = true, approved_by = $1, approved_at = now(), assigned_to = $2
       WHERE id = $3 RETURNING *`,
      [admin_id, assigned_to, ticketId]
    );

    const ticket = update.rows[0];

    if (!ticket) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'Ticket não encontrado.' });
    }

    // 2. Busca o fcm_token do técnico
    const userRes = await client.query(
      'SELECT fcm_token, name FROM users WHERE id = $1',
      [assigned_to]
    );
    const tech = userRes.rows[0];

    // 3. Envia notificação FCM (se o token existir)
    if (tech && tech.fcm_token) {
      const message = {
        token: tech.fcm_token,
        notification: {
          title: '🛠 Novo chamado de instalação aprovado!',
          body: `Cliente: ${ticket.customer_name}, Endereço: ${ticket.customer_address}`
        },
        data: {
          ticket_id: ticket.id.toString(),
          action: 'new_ticket'
        }
      };
      await adminFirebase.messaging().send(message);
      console.log(`Notificação enviada para o técnico ID ${assigned_to}`);
    } else {
        console.warn(`Token FCM não encontrado ou inválido para o técnico ID ${assigned_to}`);
    }

    await client.query('COMMIT');
    res.json({ ticket, notification_sent: !!(tech && tech.fcm_token) });

  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Erro em PUT /tickets/:id/approve:', err);
    res.status(500).json({ error: 'Erro ao aprovar ticket e enviar notificação', details: err.message });
  } finally {
    client.release();
  }
});

// ===============================================
// 7️⃣ Rota: Técnico lista tickets aprovados
// ===============================================
app.get('/tickets/assigned/:tech_id', async (req, res) => {
  const techId = req.params.tech_id;

  try {
    const result = await pool.query(
      'SELECT * FROM tickets WHERE approved = true AND assigned_to = $1 ORDER BY created_at DESC',
      [techId]
    );
    res.json({ tickets: result.rows });
  } catch (err) {
    console.error('Erro em GET /tickets/assigned/:tech_id:', err);
    res.status(500).json({ error: 'Erro ao listar tickets' });
  }
});


// ===============================================
// Inicialização do Servidor
// ===============================================
app.listen(PORT, () => {
  console.log(`Servidor Express rodando na porta ${PORT}`);
  console.log(`Para testar, use: http://localhost:${PORT}`);
});