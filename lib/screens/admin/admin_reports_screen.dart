import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../services/access_provider.dart';
import '../../services/demo_data.dart';
import '../../services/report_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  late DateTimeRange _range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 6)),
    end: DateTime.now(),
  );
  bool _exporting = false;

  Future<void> _pick() async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: _range,
    );
    if (r != null) setState(() => _range = r);
  }

  Future<void> _export(List<EmployeeReportRow> rows) async {
    setState(() => _exporting = true);
    try {
      await ReportService.exportPdf(rows, _range);
    } catch (e) {
      if (mounted) snack(context, 'Could not generate report: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final emps = context.watch<AccessProvider>().approved;
    final rows = ReportService.build(emps, _range);
    final days = <DateTime>[];
    for (var d = DemoData.day(_range.start); !d.isAfter(DemoData.day(_range.end)); d = d.add(const Duration(days: 1))) {
      days.add(d);
    }
    final daily = [for (final d in days) emps.fold<double>(0, (a, e) => a + DemoData.hours(e.id, d))];
    final f = DateFormat('d MMM');

    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
      Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _pick,
            icon: const Icon(Icons.date_range),
            label: Text('${f.format(_range.start)} – ${f.format(_range.end)}'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: _exporting ? null : () => _export(rows),
          icon: _exporting ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.picture_as_pdf),
          label: const Text('Export'),
          style: FilledButton.styleFrom(minimumSize: const Size(110, 48)),
        ),
      ]),
      const SectionTitle('Performance Intelligence'),
      _ChartCard(
        title: 'Daily Hours Distribution',
        child: _bars(
          values: daily,
          label: (i) => days.length > 10 ? (i % 3 == 0 ? '${days[i].day}' : '') : DateFormat('E').format(days[i]),
          color: AppColors.accent,
        ),
      ),
      const SizedBox(height: 12),
      _ChartCard(
        title: 'Task Completion',
        child: _bars(
          values: [for (final r in rows) r.visits.toDouble()],
          label: (i) => rows[i].employee.name.split(' ').first,
          color: AppColors.green,
        ),
      ),
      const SizedBox(height: 12),
      _ChartCard(
        title: 'Total Hours',
        child: _bars(
          values: [for (final r in rows) r.hours],
          label: (i) => rows[i].employee.name.split(' ').first,
          color: AppColors.amber,
        ),
      ),
    ]);
  }

  Widget _bars({required List<double> values, required String Function(int) label, required Color color}) {
    if (values.isEmpty) return const EmptyState(Icons.bar_chart, 'No data in this range');
    return BarChart(BarChartData(
      alignment: BarChartAlignment.spaceAround,
      gridData: const FlGridData(drawVerticalLine: false),
      borderData: FlBorderData(show: false),
      barTouchData: BarTouchData(enabled: true),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(),
        rightTitles: const AxisTitles(),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            getTitlesWidget: (v, meta) => SideTitleWidget(
              meta: meta,
              child: Text(label(v.toInt()), style: const TextStyle(fontSize: 10, color: AppColors.muted)),
            ),
          ),
        ),
      ),
      barGroups: [
        for (var i = 0; i < values.length; i++)
          BarChartGroupData(x: i, barRods: [
            BarChartRodData(toY: values[i], color: color, width: values.length > 10 ? 6 : 14, borderRadius: BorderRadius.circular(4)),
          ]),
      ],
    ));
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            SizedBox(height: 180, child: child),
          ]),
        ),
      );
}
