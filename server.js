require('dotenv').config();

const { createApp } = require('./src/app');
const { ensureDatabase } = require('./src/bootstrap/ensure-database');

const PORT = process.env.PORT || 10000;
const app = createApp();

async function startServer() {
    try {
        await ensureDatabase();

        app.listen(PORT, () => {
            console.log(`Servidor rodando na porta ${PORT}`);
            const baseUrl = process.env.RENDER_EXTERNAL_URL || `http://localhost:${PORT}`;
            console.log(`Base URL: ${baseUrl}`);
        });
    } catch (error) {
        console.error('Erro ao iniciar servidor:', error);
        process.exit(1);
    }
}

startServer();
