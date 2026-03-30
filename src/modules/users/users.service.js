const bcrypt = require('bcrypt');
const { AppError } = require('../../shared/errors/app-error');
const { ROLES } = require('../../shared/constants/roles');
const usersRepository = require('./users.repository');

async function updatePassword({ requester, userId, oldPassword, newPassword }) {
    if (!Number.isInteger(userId) || userId <= 0) {
        throw new AppError('ID de usuário inválido.', 400);
    }

    if (!newPassword || newPassword.trim().length < 6) {
        throw new AppError('Nova senha é obrigatória e deve ter pelo menos 6 caracteres.', 400);
    }

    const isAdmin = requester.role === ROLES.ADMIN;
    const isOwnAccount = Number(requester.id) === userId;

    if (!isAdmin && !isOwnAccount) {
        throw new AppError('Acesso negado. Você só pode mudar sua própria senha.', 403);
    }

    const user = await usersRepository.findUserPasswordHashById(userId);
    if (!user) {
        throw new AppError('Usuário não encontrado.', 404);
    }

    if (!isAdmin) {
        if (!oldPassword) {
            throw new AppError('Senha antiga é obrigatória para não administradores.', 400);
        }

        const oldPasswordMatches = await bcrypt.compare(oldPassword, user.password_hash);
        if (!oldPasswordMatches) {
            throw new AppError('Senha antiga incorreta.', 401);
        }
    }

    const newPasswordHash = await bcrypt.hash(newPassword.trim(), 10);
    await usersRepository.updatePasswordHash(userId, newPasswordHash);
}

async function listUsers() {
    return usersRepository.listUsers();
}

async function listTechnicians() {
    return usersRepository.listTechnicians();
}

module.exports = {
    updatePassword,
    listUsers,
    listTechnicians,
};
