import '../../features/scheduling/domain/create_schedule_input.dart';

class ScheduleDescriptionMetadata {
  ScheduleDescriptionMetadata({
    this.desiredDateLabel,
    this.vehicleSummary,
    this.sellerNotes,
    this.technicalDetails,
    this.contactPhone,
  });

  final String? desiredDateLabel;
  final String? vehicleSummary;
  final String? sellerNotes;
  final String? technicalDetails;
  final String? contactPhone;
}

class ScheduleDescriptionCodec {
  static String encode(CreateScheduleInput input) {
    final lines = <String>[
      'Data desejada: ${input.desiredDateIso}',
      'Veículo: ${input.vehicle.summary}',
      'Telefone: ${input.customer.phone}',
      'Observações do vendedor: ${input.sellerNotes}',
      'Detalhes operacionais: ${input.serviceDescription}',
    ];

    return lines.join('\n');
  }

  static ScheduleDescriptionMetadata decode(String description) {
    String? extract(String prefix) {
      final match = description
          .split('\n')
          .cast<String?>()
          .firstWhere((line) => line?.startsWith(prefix) ?? false, orElse: () => null);

      if (match == null) {
        return null;
      }

      return match.replaceFirst(prefix, '').trim();
    }

    return ScheduleDescriptionMetadata(
      desiredDateLabel: extract('Data desejada:'),
      vehicleSummary: extract('Veículo:'),
      contactPhone: extract('Telefone:'),
      sellerNotes: extract('Observações do vendedor:'),
      technicalDetails: extract('Detalhes operacionais:'),
    );
  }
}
