const { AppError } = require('../errors/app-error');

function notFoundHandler(req, res) {
    res.status(404).json({
        success: false,
        message: 'Rota não encontrada.',
        path: req.originalUrl,
    });
}

function errorHandler(err, req, res, next) { // eslint-disable-line no-unused-vars
    const appError = err instanceof AppError
        ? err
        : new AppError('Erro interno no servidor.', 500, err.message);

    if (appError.statusCode >= 500) {
        console.error('Erro interno:', err);
    }

    res.status(appError.statusCode).json({
        success: false,
        message: appError.message,
        details: appError.details,
        path: req.originalUrl,
    });
}

module.exports = {
    notFoundHandler,
    errorHandler,
};
