class Vehicle {
  const Vehicle({
    required this.model,
    required this.plate,
    this.year,
    this.color,
  });

  final String model;
  final String plate;
  final String? year;
  final String? color;

  String get summary {
    final parts = <String>[
      model,
      if (plate.trim().isNotEmpty) 'Placa $plate',
      if ((year ?? '').trim().isNotEmpty) 'Ano $year',
      if ((color ?? '').trim().isNotEmpty) color!,
    ];

    return parts.join(' | ');
  }
}
