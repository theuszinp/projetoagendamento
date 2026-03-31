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

async function completedServices({ from, to, search }) {
    const toDate = to ? new Date(to) : new Date();
    const fromDate = from
        ? new Date(from)
        : new Date(toDate.getTime() - 30 * 24 * 60 * 60 * 1000);

    if (Number.isNaN(fromDate.getTime()) || Number.isNaN(toDate.getTime())) {
        throw new AppError('Parâmetros from/to inválidos. Use YYYY-MM-DD.', 400);
    }

    const rows = await reportsRepository.listCompletedServices({
        from: fromDate.toISOString().slice(0, 10),
        to: toDate.toISOString().slice(0, 10),
        search,
    });

    const completedWithDuration = rows.filter((row) => row.duration_min != null);
    const totalMinutes = completedWithDuration.reduce(
        (accumulator, row) => accumulator + Number(row.duration_min || 0),
        0
    );
    const technicians = new Set(rows.map((row) => Number(row.tech_id)).filter(Boolean));
    const servicesWithPhotos = rows.filter((row) => Number(row.attachments_count || 0) > 0).length;

    return {
        range: {
            from: fromDate.toISOString().slice(0, 10),
            to: toDate.toISOString().slice(0, 10),
        },
        summary: {
            total_services: rows.length,
            total_minutes: Number(totalMinutes.toFixed(2)),
            avg_minutes:
                completedWithDuration.length > 0
                    ? Number((totalMinutes / completedWithDuration.length).toFixed(2))
                    : 0,
            technicians_involved: technicians.size,
            services_with_photos: servicesWithPhotos,
        },
        rows,
    };
}

module.exports = {
    techSummary,
    completedServices,
};
