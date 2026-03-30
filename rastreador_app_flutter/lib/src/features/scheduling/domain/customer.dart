class Customer {
  const Customer({
    required this.name,
    required this.document,
    required this.phone,
    this.id,
  });

  final int? id;
  final String name;
  final String document;
  final String phone;
}
