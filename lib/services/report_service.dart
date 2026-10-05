import 'package:flutter/material.dart' show DateTimeRange;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/models.dart';
import 'demo_data.dart';

class EmployeeReportRow {
  final Employee employee;
  final double hours;
  final int visits;
  final double km;
  EmployeeReportRow(this.employee, this.hours, this.visits, this.km);
}

class ReportService {
  static List<EmployeeReportRow> build(List<Employee> employees, DateTimeRange range) {
    final days = <DateTime>[];
    for (var d = DemoData.day(range.start);
        !d.isAfter(DemoData.day(range.end));
        d = d.add(const Duration(days: 1))) {
      days.add(d);
    }
    return [
      for (final e in employees)
        EmployeeReportRow(
          e,
          days.fold(0.0, (a, d) => a + DemoData.hours(e.id, d)),
          days.fold(0, (a, d) => a + DemoData.visitsDone(e.id, d)),
          days.fold(0.0, (a, d) => a + DemoData.km(e.id, d)),
        ),
    ];
  }

  static Future<void> exportPdf(List<EmployeeReportRow> rows, DateTimeRange range) async {
    final f = DateFormat('d MMM y');
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      build: (_) => [
        pw.Text('FieldFlow – Performance Report', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
        pw.Text('${f.format(range.start)} – ${f.format(range.end)}'),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headers: ['Employee', 'District', 'Hours', 'Visits', 'Distance (km)'],
          data: [
            for (final r in rows)
              [r.employee.name, r.employee.district, r.hours.toStringAsFixed(1), '${r.visits}', r.km.toStringAsFixed(1)],
          ],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo),
        ),
      ],
    ));
    await Printing.layoutPdf(name: 'fieldflow_report.pdf', onLayout: (_) => doc.save());
  }
}
