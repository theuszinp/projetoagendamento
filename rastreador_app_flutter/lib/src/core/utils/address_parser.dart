class ParsedAddress {
  const ParsedAddress({
    this.street = '',
    this.number = '',
    this.complement = '',
    this.district = '',
    this.city = '',
    this.state = '',
    this.cep = '',
  });

  final String street;
  final String number;
  final String complement;
  final String district;
  final String city;
  final String state;
  final String cep;
}

class AddressParser {
  static ParsedAddress parse(String fullAddress) {
    final raw = fullAddress.trim();
    if (raw.isEmpty) {
      return const ParsedAddress();
    }

    final cepMatch = RegExp(r'CEP\s*([0-9\-]+)$', caseSensitive: false)
        .firstMatch(raw);
    final cep = cepMatch?.group(1)?.trim() ?? '';
    final withoutCep = raw.replaceFirst(RegExp(r'\s*-\s*CEP\s*[0-9\-]+$', caseSensitive: false), '');

    final segments = withoutCep.split(' - ');
    final firstPart = segments.isNotEmpty ? segments.first.trim() : '';
    final secondPart = segments.length > 1 ? segments[1].trim() : '';

    final firstTokens = firstPart.split(',');
    final street = firstTokens.isNotEmpty ? firstTokens.first.trim() : '';
    final number = firstTokens.length > 1 ? firstTokens[1].trim() : '';
    final complement = firstTokens.length > 2
        ? firstTokens.sublist(2).join(',').trim()
        : '';

    final secondTokens = secondPart.split(',');
    final district = secondTokens.isNotEmpty ? secondTokens.first.trim() : '';
    final cityState = secondTokens.length > 1 ? secondTokens[1].trim() : '';
    final cityStateParts = cityState.split('/');
    final city = cityStateParts.isNotEmpty ? cityStateParts.first.trim() : '';
    final state =
        cityStateParts.length > 1 ? cityStateParts[1].trim().toUpperCase() : '';

    return ParsedAddress(
      street: street,
      number: number,
      complement: complement,
      district: district,
      city: city,
      state: state,
      cep: cep,
    );
  }
}
