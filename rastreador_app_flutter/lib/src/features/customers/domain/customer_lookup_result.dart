class CustomerLookupResult {
  const CustomerLookupResult({
    required this.id,
    required this.name,
    required this.document,
    required this.phone,
    required this.address,
  });

  final int id;
  final String name;
  final String document;
  final String phone;
  final String address;
}
