const { AppError } = require('../../shared/errors/app-error');
const reportsRepository = require('./reports.repository');

async function techSummary({ from, to }) {
    const toDate = to ? new Date(to) : new Date();
    const fromDate = from
        ? new Date(from)
        : new Date(toDate.getTime() - 30 * 24 * 60 * 60 * 1000);

    if (Number.isNaN(fromDate.getTime()) || Number.isNaN(toDate.getTime())) {
        throw new AppError('Parâmetros from/to inválidos. Use YYYY-MM-DD.', 400);
    }

    const rows = await reportsRepository.listTechSummary({
        from: fromDate.toISOString().slice(0, 10),
        to: toDate.toISOString().slice(0, 10),
    });

    return {
        range: {
            from: fromDate.toISOString().slice(0, 10),
            to: toDate.toISOString().slice(0, 10),
        },
        rows,
    };
}

module.exports = {
    techSummary,
};
