const customersService = require('./customers.service');

async function search(req, res) {
    const customer = await customersService.searchByIdentifier(req.query.identifier);
    res.json({
        success: true,
        client: customer,
    });
}

module.exports = { search };
