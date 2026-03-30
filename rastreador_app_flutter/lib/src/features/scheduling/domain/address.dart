class Address {
  const Address({
    required this.fullText,
    this.reference,
  });

  final String fullText;
  final String? reference;

  bool get isValid => fullText.trim().isNotEmpty;
}
