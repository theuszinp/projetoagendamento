const reportsService = require('./reports.service');

async function techSummary(req, res) {
    const result = await reportsService.techSummary(req.query);
    res.json({
        success: true,
        ...result,
    });
}

module.exports = { techSummary };
