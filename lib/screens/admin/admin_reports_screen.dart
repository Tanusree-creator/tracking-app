import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/access_provider.dart';
import '../../services/api.dart';
import '../../services/report_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/glass.dart';
import '../../l10n/l10n.dart';

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
  String? _employeeId; // null = all employees
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _exporting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final from = DateTime(_range.start.year, _range.start.month, _range.start.day);
      final to = DateTime(_range.end.year, _range.end.month, _range.end.day, 23, 59, 59);
      final d = await Api.adminReportData(from, to);
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _error = '${e.toString().replaceFirst('Exception: ', '')}\n(Run supabase/004_field_sync.sql if you have not yet.)');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pick() async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: _range,
    );
    if (r != null) {
      setState(() => _range = r);
      _load();
    }
  }

  Future<void> _export(List<EmpReport> rows, Employee? selected) async {
    setState(() => _exporting = true);
    try {
      await ReportService.exportPdf(rows, _range, selected: selected);
    } catch (e) {
      if (mounted) snack(context, 'Could not generate report: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final emps = context.watch<AccessProvider>().approved;
    final selected = emps.where((e) => e.id == _employeeId).firstOrNull;
    final f = DateFormat('d MMM');

    final controls = Column(children: [
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
          onPressed: _exporting || _data == null ? null : () => _export(ReportService.build(emps, _data!), selected),
          icon: _exporting ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.picture_as_pdf),
          label: Text('PDF'.tr),
          style: FilledButton.styleFrom(minimumSize: const Size(100, 48)),
        ),
      ]),
      const SizedBox(height: 12),
      DropdownButtonFormField<String?>(
        initialValue: _employeeId,
        isExpanded: true,
        decoration: InputDecoration(labelText: 'Employee'.tr, prefixIcon: Icon(Icons.person_outline)),
        items: [
          DropdownMenuItem<String?>(value: null, child: Text('All employees'.tr)),
          for (final e in emps) DropdownMenuItem<String?>(value: e.id, child: Text(e.name, overflow: TextOverflow.ellipsis)),
        ],
        onChanged: (v) => setState(() => _employeeId = v),
      ),
    ]);

    Widget body;
    if (_loading) {
      body = const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()));
    } else if (_error != null) {
      body = ErrorState(_error!, _load);
    } else {
      final rows = ReportService.build(emps, _data!);
      final scope = selected == null ? rows : rows.where((r) => r.employee.id == selected.id).toList();
      final days = ReportService.days(_range);
      final daily = [for (final d in days) scope.fold<double>(0, (a, r) => a + (r.hoursByDay[d] ?? 0))];
      final doneDaily = [for (final d in days) scope.fold<double>(0, (a, r) => a + (r.doneByDay[d] ?? 0))];
      final cumulative = <double>[];
      for (final v in daily) {
        cumulative.add((cumulative.isEmpty ? 0 : cumulative.last) + v);
      }
      final totalHours = scope.fold(0.0, (a, r) => a + r.hours);
      final total = scope.fold(0, (a, r) => a + r.tasksTotal);
      final done = scope.fold(0, (a, r) => a + r.tasksDone);
      String dayLabel(int i) => days.length > 10 ? (i % 3 == 0 ? '${days[i].day}' : '') : DateFormat('E').format(days[i]);
      body = Column(children: [
        Row(children: [
          Expanded(
            child: GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Total hours'.tr, style: TextStyle(color: AppColors.muted, fontSize: 13)),
                  const SizedBox(height: 6),
                  CountUp(totalHours, decimals: 1, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  DonutProgress(
                    value: total == 0 ? 0 : done / total,
                    size: 64,
                    stroke: 8,
                    center: Text(total == 0 ? '–' : '${(100 * done / total).round()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Tasks'.tr, style: TextStyle(color: AppColors.muted, fontSize: 13)),
                      Text('$done / $total', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        _ChartCard(title: 'Daily Hours Distribution'.tr, child: _bars(values: daily, label: dayLabel, color: AppColors.accent, days: days.length)),
        const SizedBox(height: 12),
        _ChartCard(
          title: selected == null ? 'Task Completion (by employee)' : 'Task Completion (by day)',
          child: selected == null
              ? _bars(values: [for (final r in rows) r.tasksDone.toDouble()], label: (i) => rows[i].employee.name.split(' ').first, color: AppColors.blue700, days: rows.length)
              : _bars(values: doneDaily, label: dayLabel, color: AppColors.blue700, days: days.length),
        ),
        const SizedBox(height: 12),
        _ChartCard(
          title: selected == null ? 'Total Hours (by employee)' : 'Total Hours (running total)',
          child: selected == null
              ? _bars(values: [for (final r in rows) r.hours], label: (i) => rows[i].employee.name.split(' ').first, color: AppColors.blue400, days: rows.length)
              : _bars(values: cumulative, label: dayLabel, color: AppColors.blue400, days: days.length, line: true),
        ),
      ]);
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
        controls,
        const SectionTitle('Performance'),
        body,
      ]),
    );
  }

  Widget _bars({required List<double> values, required String Function(int) label, required Color color, required int days, bool line = false}) {
    if (values.isEmpty || values.every((v) => v == 0)) return const EmptyState(Icons.bar_chart, 'No data in this range');
    final titles = FlTitlesData(
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
    );
    if (line) {
      return LineChart(LineChartData(
        gridData: const FlGridData(drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: titles,
        minY: 0,
        lineBarsData: [
          LineChartBarData(
            spots: [for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i])],
            isCurved: true,
            color: color,
            barWidth: 3,
            dotData: FlDotData(show: values.length <= 14),
            belowBarData: BarAreaData(show: true, color: color.withValues(alpha: .15)),
          ),
        ],
      ));
    }
    return BarChart(BarChartData(
      alignment: BarChartAlignment.spaceAround,
      gridData: const FlGridData(drawVerticalLine: false),
      borderData: FlBorderData(show: false),
      barTouchData: BarTouchData(enabled: true),
      titlesData: titles,
      barGroups: [
        for (var i = 0; i < values.length; i++)
          BarChartGroupData(x: i, barRods: [
            BarChartRodData(toY: values[i], color: color, width: days > 10 ? 6 : 14, borderRadius: BorderRadius.circular(4)),
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
  Widget build(BuildContext context) => GlassCard(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title.tr, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            SizedBox(height: 180, child: child),
          ]),
        ),
      ).enter();
}
