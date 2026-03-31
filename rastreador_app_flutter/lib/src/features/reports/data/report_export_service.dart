import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/completed_services_report.dart';

class ReportExportService {
  Future<File> generateCompletedServicesWorkbook(
    CompletedServicesReport report,
  ) async {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
    excel.rename(defaultSheet, 'Servicos');
    final sheet = excel['Servicos'];

    sheet.appendRow([
      TextCellValue('Relatorio de servicos concluidos'),
    ]);
    sheet.appendRow([
      TextCellValue(
        'Periodo ${_date(report.from)} ate ${_date(report.to)}',
      ),
    ]);
    sheet.appendRow([
      TextCellValue('Total'),
      IntCellValue(report.summary.totalServices),
      TextCellValue('Com fotos'),
      IntCellValue(report.summary.servicesWithPhotos),
      TextCellValue('Tempo medio (min)'),
      DoubleCellValue(report.summary.averageMinutes),
    ]);
    sheet.appendRow(const []);
    sheet.appendRow([
      TextCellValue('Protocolo'),
      TextCellValue('Servico'),
      TextCellValue('Cliente'),
      TextCellValue('Endereco'),
      TextCellValue('Vendedor'),
      TextCellValue('Instalador'),
      TextCellValue('Inicio'),
      TextCellValue('Conclusao'),
      TextCellValue('Duracao (min)'),
      TextCellValue('Fotos'),
    ]);

    for (final item in report.items) {
      sheet.appendRow([
        TextCellValue('AG-${item.ticketId.toString().padLeft(5, '0')}'),
        TextCellValue(item.title),
        TextCellValue(item.customerName),
        TextCellValue(item.customerAddress),
        TextCellValue(item.sellerName),
        TextCellValue(item.technicianName),
        TextCellValue(_dateTime(item.startedAt)),
        TextCellValue(_dateTime(item.completedAt)),
        DoubleCellValue(item.durationMinutes),
        IntCellValue(item.attachmentsCount),
      ]);
    }

    sheet.setColumnWidth(0, 14);
    sheet.setColumnWidth(1, 26);
    sheet.setColumnWidth(2, 24);
    sheet.setColumnWidth(3, 34);
    sheet.setColumnWidth(4, 20);
    sheet.setColumnWidth(5, 20);
    sheet.setColumnWidth(6, 20);
    sheet.setColumnWidth(7, 20);
    sheet.setColumnWidth(8, 16);
    sheet.setColumnWidth(9, 10);

    final bytes = excel.save();
    if (bytes == null) {
      throw Exception('Nao foi possivel gerar o arquivo Excel.');
    }

    final baseDirectory =
        await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    if (!baseDirectory.existsSync()) {
      baseDirectory.createSync(recursive: true);
    }

    final file = File(
      '${baseDirectory.path}${Platform.pathSeparator}${_fileName(report)}',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  String _fileName(CompletedServicesReport report) {
    final from = _date(report.from).replaceAll('/', '-');
    final to = _date(report.to).replaceAll('/', '-');
    return 'relatorio_servicos_${from}_$to.xlsx';
  }

  String _date(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/'
        '${value.year}';
  }

  String _dateTime(DateTime? value) {
    if (value == null) {
      return '-';
    }

    return '${_date(value)} '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }
}
