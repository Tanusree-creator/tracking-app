import 'package:flutter/material.dart' show DateTimeRange;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/models.dart';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// One employee's numbers for a date range.
class EmpReport {
  final Employee employee;
  final double hours;
  final int tasksTotal;
  final int tasksDone;
  final Map<DateTime, double> hoursByDay;
  final Map<DateTime, int> doneByDay;
  const EmpReport(this.employee, this.hours, this.tasksTotal, this.tasksDone, this.hoursByDay, this.doneByDay);

  double get completion => tasksTotal == 0 ? 0 : tasksDone / tasksTotal;
}

class ReportService {
  static List<DateTime> days(DateTimeRange r) {
    final out = <DateTime>[];
    for (var d = _day(r.start); !d.isAfter(_day(r.end)); d = d.add(const Duration(days: 1))) {
      out.add(d);
    }
    return out;
  }

  /// [data] is the `admin_report_data` payload.
  static List<EmpReport> build(List<Employee> employees, Map<String, dynamic> data) {
    final shifts = (data['shifts'] as List).cast<Map>();
    final visits = (data['visits'] as List).cast<Map>();
    return [
      for (final e in employees)
        () {
          final hoursByDay = <DateTime, double>{};
          for (final s in shifts.where((s) => s['user_id'] == e.id)) {
            final shift = Shift.fromRemote({'id': '', 'start': s['start'], 'end': s['end'], 'breaks': s['breaks']});
            final d = _day(shift.start);
            hoursByDay[d] = (hoursByDay[d] ?? 0) + shift.worked.inMinutes / 60;
          }
          final mine = visits.where((v) => v['user_id'] == e.id).toList();
          final doneByDay = <DateTime, int>{};
          for (final v in mine.where((v) => v['status'] == 'completed')) {
            final d = _day(DateTime.parse(v['scheduled_time'] as String).toLocal());
            doneByDay[d] = (doneByDay[d] ?? 0) + 1;
          }
          return EmpReport(e, hoursByDay.values.fold(0.0, (a, b) => a + b), mine.length,
              mine.where((v) => v['status'] == 'completed').length, hoursByDay, doneByDay);
        }(),
    ];
  }

  // ── PDF ────────────────────────────────────────────────────────────────────
  static const _blue = PdfColor.fromInt(0xFF1D6FFF);
  static const _navy = PdfColor.fromInt(0xFF0B1E4F);
  static const _track = PdfColor.fromInt(0xFFE3ECFF);

  static pw.Widget _bars(List<double> values, List<String> labels, {PdfColor color = _blue}) {
    final max = values.fold(0.0, (a, b) => b > a ? b : a);
    return pw.Container(
      height: 150,
      padding: const pw.EdgeInsets.fromLTRB(4, 14, 4, 0),
      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400))),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        for (var i = 0; i < values.length; i++)
          pw.Expanded(
            child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
              if (values.length <= 16) pw.Text(values[i] == 0 ? '' : values[i].toStringAsFixed(1), style: const pw.TextStyle(fontSize: 7)),
              pw.Container(
                width: values.length > 16 ? 6 : 14,
                height: max == 0 ? 2 : (110 * values[i] / max).clamp(2, 110).toDouble(),
                decoration: pw.BoxDecoration(color: color, borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(3))),
              ),
            ]),
          ),
      ]),
    );
  }

  static pw.Widget _labels(List<String> labels) => pw.Row(children: [
        for (final l in labels) pw.Expanded(child: pw.Center(child: pw.Text(l, style: const pw.TextStyle(fontSize: 7)))),
      ]);

  static pw.Widget _card(String title, pw.Widget body) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 14),
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(8)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: _navy)),
          pw.SizedBox(height: 8),
          body,
        ]),
      );

  static pw.Widget _meter(double v) => pw.Stack(children: [
        pw.Container(height: 14, decoration: pw.BoxDecoration(color: _track, borderRadius: pw.BorderRadius.circular(7))),
        pw.Container(
            height: 14,
            width: 440 * v.clamp(0, 1),
            decoration: pw.BoxDecoration(color: _blue, borderRadius: pw.BorderRadius.circular(7))),
      ]);

  /// Exports the selected employee (or everyone when [selected] is null) as a PDF with the same charts as the screen.
  static Future<void> exportPdf(List<EmpReport> rows, DateTimeRange range, {Employee? selected}) async {
    final f = DateFormat('d MMM y');
    final dayList = days(range);
    final focus = selected == null ? null : rows.where((r) => r.employee.id == selected.id).firstOrNull;
    final scope = focus == null ? rows : [focus];
    final totalHours = scope.fold(0.0, (a, r) => a + r.hours);
    final total = scope.fold(0, (a, r) => a + r.tasksTotal);
    final done = scope.fold(0, (a, r) => a + r.tasksDone);
    final dailyHours = [for (final d in dayList) scope.fold(0.0, (a, r) => a + (r.hoursByDay[d] ?? 0))];
    final dayLabels = [for (final d in dayList) dayList.length > 16 ? (d.day % 3 == 0 ? '${d.day}' : '') : DateFormat('d/M').format(d)];
    final doneDaily = [for (final d in dayList) scope.fold(0.0, (a, r) => a + (r.doneByDay[d] ?? 0))];
    final names = [for (final r in rows) r.employee.name.split(' ').first];

    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      margin: const pw.EdgeInsets.all(32),
      header: (_) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 10),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('Merit Publication', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: _blue)),
          pw.Text('${f.format(range.start)} – ${f.format(range.end)}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        ]),
      ),
      footer: (c) => pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text('Page ${c.pageNumber} / ${c.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600))),
      build: (_) => [
        pw.Text(focus == null ? 'Performance Report – All employees' : 'Performance Report – ${focus.employee.name}',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: _navy)),
        if (focus != null) pw.Text('${focus.employee.title} · ${focus.employee.district}', style: const pw.TextStyle(color: PdfColors.grey700)),
        pw.SizedBox(height: 14),
        pw.Row(children: [
          for (final (label, value) in [
            ('Total hours', totalHours.toStringAsFixed(1)),
            ('Tasks completed', '$done / $total'),
            ('Completion', total == 0 ? '–' : '${(100 * done / total).round()}%'),
          ])
            pw.Expanded(
              child: pw.Container(
                margin: const pw.EdgeInsets.only(right: 8),
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(color: _track, borderRadius: pw.BorderRadius.circular(8)),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  pw.Text(value, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: _navy)),
                ]),
              ),
            ),
        ]),
        pw.SizedBox(height: 14),
        _card('Daily hours distribution', pw.Column(children: [_bars(dailyHours, dayLabels), _labels(dayLabels)])),
        _card('Task completion', pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('$done of $total tasks completed', style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 6),
          _meter(total == 0 ? 0 : done / total),
          pw.SizedBox(height: 12),
          _bars(doneDaily, dayLabels, color: _navy),
          _labels(dayLabels),
        ])),
        if (focus == null) ...[
          _card('Total hours per employee', pw.Column(children: [_bars([for (final r in rows) r.hours], names), _labels(names)])),
          _card('Tasks completed per employee',
              pw.Column(children: [_bars([for (final r in rows) r.tasksDone.toDouble()], names, color: _navy), _labels(names)])),
        ],
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headers: ['Employee', 'District', 'Hours', 'Tasks done', 'Total tasks', 'Completion'],
          data: [
            for (final r in scope)
              [r.employee.name, r.employee.district, r.hours.toStringAsFixed(1), '${r.tasksDone}', '${r.tasksTotal}', r.tasksTotal == 0 ? '–' : '${(r.completion * 100).round()}%'],
          ],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
          headerDecoration: const pw.BoxDecoration(color: _blue),
          cellStyle: const pw.TextStyle(fontSize: 10),
          oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF3F7FF)),
        ),
      ],
    ));
    final fileName = focus == null ? 'fieldflow_report' : 'fieldflow_${focus.employee.name.toLowerCase().replaceAll(' ', '_')}';
    await Printing.layoutPdf(name: '$fileName.pdf', onLayout: (_) => doc.save());
  }
}
