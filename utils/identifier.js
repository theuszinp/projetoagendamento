function normalizeIdentifier(value) {
    if (value === undefined || value === null) {
        return '';
    }
    return String(value).replace(/\D/g, '');
}

function isValidIdentifier(normalizedIdentifier) {
    return normalizedIdentifier.length === 11 || normalizedIdentifier.length === 14;
}

module.exports = { normalizeIdentifier, isValidIdentifier };
