const jwt = require('jsonwebtoken');

// JWT Auth Middleware
function authMiddleware(req, res, next) {
    const header = req.headers['authorization'];
    if (!header) {
        return res.status(401).json({ success: false, message: 'Token ausente.' });
    }

    const parts = header.split(' ');
    if (parts.length !== 2 || parts[0] !== 'Bearer') {
        return res.status(401).json({ success: false, message: 'Formato do token inválido.' });
    }

    const token = parts[1];
    try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        req.user = decoded; // Ex: { id, role }
        return next();
    } catch (err) {
        return res.status(403).json({ success: false, message: 'Token inválido ou expirado.' });
    }
}

// Role Middleware
function roleMiddleware(requiredRole) {
    return (req, res, next) => {
        if (!req.user || req.user.role !== requiredRole) {
            return res.status(403).json({ success: false, message: `Acesso negado. Requer role: ${requiredRole}` });
        }
        return next();
    };
}

module.exports = { authMiddleware, roleMiddleware };
