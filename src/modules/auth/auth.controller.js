const authService = require('./auth.service');

async function login(req, res) {
    const result = await authService.login(req.body);
    res.json({
        success: true,
        message: 'Login realizado com sucesso.',
        ...result,
    });
}

async function register(req, res) {
    await authService.register(req.body);
    res.status(201).json({
        success: true,
        message: 'Cadastro realizado. Aguarde aprovação do administrador.',
    });
}

async function approveUser(req, res) {
    await authService.approveUser(Number(req.params.id));
    res.json({
        success: true,
        message: 'Usuário aprovado com sucesso.',
    });
}

async function listPendingUsers(req, res) {
    const users = await authService.listPendingUsers();
    res.json({
        success: true,
        users,
    });
}

module.exports = {
    login,
    register,
    approveUser,
    listPendingUsers,
};
