const jwt = require('jsonwebtoken');
const { AppError } = require('../errors/app-error');

function authenticate(req, res, next) {
    const authorizationHeader = req.headers.authorization;

    if (!authorizationHeader) {
        return next(new AppError('Token ausente.', 401));
    }

    const [scheme, token] = authorizationHeader.split(' ');

    if (scheme !== 'Bearer' || !token) {
        return next(new AppError('Formato do token inválido.', 401));
    }

    try {
        req.user = jwt.verify(token, process.env.JWT_SECRET);
        return next();
    } catch (error) {
        return next(new AppError('Token inválido ou expirado.', 403));
    }
}

function authorizeRoles(...allowedRoles) {
    return (req, res, next) => {
        if (!req.user || !allowedRoles.includes(req.user.role)) {
            return next(new AppError('Acesso negado.', 403));
        }

        return next();
    };
}

module.exports = {
    authenticate,
    authorizeRoles,
};
