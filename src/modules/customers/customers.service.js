const { AppError } = require('../../shared/errors/app-error');
const {
    normalizeIdentifier,
    isValidIdentifier,
} = require('../../shared/utils/identifier');
const customersRepository = require('./customers.repository');

async function searchByIdentifier(identifier) {
    if (!identifier || identifier.trim() === '') {
        throw new AppError('O identificador (CPF/CNPJ) do cliente é obrigatório.', 400);
    }

    const normalizedIdentifier = normalizeIdentifier(identifier);
    if (!isValidIdentifier(normalizedIdentifier)) {
        throw new AppError('O CPF/CNPJ informado é inválido.', 400);
    }

    const customer = await customersRepository.findByNormalizedIdentifier(normalizedIdentifier);
    if (!customer) {
        throw new AppError('Cliente não encontrado.', 404);
    }

    return {
        id: customer.id,
        name: customer.name,
        address: customer.address,
        identifier: customer.identifier,
        phoneNumber: customer.phone_number,
    };
}

module.exports = {
    searchByIdentifier,
};
