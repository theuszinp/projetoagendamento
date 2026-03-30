const usersService = require('./users.service');

async function updatePassword(req, res) {
    await usersService.updatePassword({
        requester: req.user,
        userId: Number(req.params.id),
        oldPassword: req.body.old_senha,
        newPassword: req.body.new_senha,
    });

    res.json({
        success: true,
        message: 'Senha atualizada com sucesso. Faça login novamente.',
    });
}

async function listUsers(req, res) {
    const users = await usersService.listUsers();
    res.json({
        success: true,
        users,
    });
}

async function listTechnicians(req, res) {
    const technicians = await usersService.listTechnicians();
    res.json({
        success: true,
        technicians,
    });
}

module.exports = {
    updatePassword,
    listUsers,
    listTechnicians,
};
