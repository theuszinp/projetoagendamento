const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { AppError } = require('../../shared/errors/app-error');
const { ROLES } = require('../../shared/constants/roles');
const authRepository = require('./auth.repository');

const ALLOWED_REGISTRATION_ROLES = new Set([ROLES.SELLER, ROLES.TECH]);

async function login({ email, senha }) {
    if (!email || !senha) {
        throw new AppError('Email e senha são obrigatórios.', 400);
    }

    const user = await authRepository.findUserByEmail(email);
    if (!user) {
        throw new AppError('Credenciais inválidas.', 401);
    }

    if (!user.approved) {
        throw new AppError('Aguardando aprovação do administrador.', 403);
    }

    const passwordMatches = await bcrypt.compare(senha, user.password_hash);
    if (!passwordMatches) {
        throw new AppError('Credenciais inválidas.', 401);
    }

    const token = jwt.sign(
        { id: user.id, role: user.role },
        process.env.JWT_SECRET,
        { expiresIn: '8h' }
    );

    return {
        token,
        user: {
            id: user.id,
            name: user.name,
            email: user.email,
            role: user.role,
            approved: user.approved,
        },
    };
}

async function register({ name, email, senha, role }) {
    if (!name || !email || !senha || !role) {
        throw new AppError('Campos obrigatórios ausentes.', 400);
    }

    if (senha.trim().length < 6) {
        throw new AppError('A senha deve ter pelo menos 6 caracteres.', 400);
    }

    if (!ALLOWED_REGISTRATION_ROLES.has(role)) {
        throw new AppError('Perfil inválido para cadastro público.', 400);
    }

    const existingUser = await authRepository.findUserByEmail(email);
    if (existingUser) {
        throw new AppError('Email já cadastrado.', 400);
    }

    const passwordHash = await bcrypt.hash(senha.trim(), 10);
    return authRepository.createUser({
        name: name.trim(),
        email: email.trim().toLowerCase(),
        passwordHash,
        role,
    });
}

async function approveUser(userId) {
    const approvedUser = await authRepository.approveUser(userId);
    if (!approvedUser) {
        throw new AppError('Usuário não encontrado.', 404);
    }

    return approvedUser;
}

async function listPendingUsers() {
    return authRepository.listPendingUsers();
}

module.exports = {
    login,
    register,
    approveUser,
    listPendingUsers,
};
