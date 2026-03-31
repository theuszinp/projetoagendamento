class CepLookupResult {
  const CepLookupResult({
    required this.cep,
    required this.street,
    required this.complement,
    required this.neighborhood,
    required this.city,
    required this.state,
    required this.stateName,
    required this.region,
    required this.ddd,
    required this.ibge,
  });

  final String cep;
  final String street;
  final String complement;
  final String neighborhood;
  final String city;
  final String state;
  final String stateName;
  final String region;
  final String ddd;
  final String ibge;

  factory CepLookupResult.fromJson(Map<String, dynamic> json) {
    return CepLookupResult(
      cep: (json['cep'] ?? '').toString(),
      street: (json['logradouro'] ?? '').toString(),
      complement: (json['complemento'] ?? '').toString(),
      neighborhood: (json['bairro'] ?? '').toString(),
      city: (json['localidade'] ?? '').toString(),
      state: (json['uf'] ?? '').toString(),
      stateName: (json['estado'] ?? '').toString(),
      region: (json['regiao'] ?? '').toString(),
      ddd: (json['ddd'] ?? '').toString(),
      ibge: (json['ibge'] ?? '').toString(),
    );
  }
}
