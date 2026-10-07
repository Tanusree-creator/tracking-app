import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackingapp/models/models.dart';
import 'package:trackingapp/services/report_service.dart';
import 'package:trackingapp/services/route_math.dart';
import 'package:trackingapp/theme/app_theme.dart';
import 'package:trackingapp/widgets/radar_orbit.dart';

void main() {
  test('routeKm ignores jitter and impossible jumps', () {
    final t = DateTime(2026, 1, 1, 9);
    final pts = [
      LocationPoint(10.0, 10.0, t),
      LocationPoint(10.00001, 10.0, t.add(const Duration(seconds: 5))), // ~1 m jitter
      LocationPoint(10.001, 10.0, t.add(const Duration(seconds: 30))), // ~111 m real move
      LocationPoint(20.0, 20.0, t.add(const Duration(seconds: 35))), // teleport
    ];
    final km = routeKm(pts);
    expect(km, inInclusiveRange(0.10, 0.12));
  });

  test('splitRoute breaks the line across a tracking gap', () {
    final t = DateTime(2026, 1, 1, 9);
    final r = splitRoute([
      LocationPoint(1, 1, t),
      LocationPoint(1.001, 1, t.add(const Duration(seconds: 10))),
      LocationPoint(1.01, 1, t.add(const Duration(minutes: 20))),
      LocationPoint(1.011, 1, t.add(const Duration(minutes: 20, seconds: 10))),
    ]);
    expect(r.solid.length, 2);
    expect(r.gaps.length, 1);
  });

  test('report build sums hours and task completion per employee', () {
    const e = Employee(id: 'u1', name: 'A B', email: 'a@b.c');
    final data = {
      'shifts': [
        {'user_id': 'u1', 'start': '2026-01-01T09:00:00Z', 'end': '2026-01-01T17:00:00Z', 'breaks': [
          {'start': '2026-01-01T12:00:00Z', 'end': '2026-01-01T13:00:00Z'}
        ]},
      ],
      'visits': [
        {'user_id': 'u1', 'status': 'completed', 'scheduled_time': '2026-01-01T10:00:00Z'},
        {'user_id': 'u1', 'status': 'pending', 'scheduled_time': '2026-01-01T11:00:00Z'},
      ],
    };
    final r = ReportService.build([e], data).single;
    expect(r.hours, closeTo(7, .01));
    expect(r.tasksDone, 1);
    expect(r.tasksTotal, 2);
  });

  testWidgets('RadarOrbit renders and opens a tapped employee', (tester) async {
    Employee? tapped;
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: Scaffold(
        body: RadarOrbit(
          employees: const [
            Employee(id: '1', name: 'Ann Lee', email: 'a@x.y', status: DutyStatus.onDuty),
            Employee(id: '2', name: 'Bo Chan', email: 'b@x.y'),
            Employee(id: '3', name: 'Cy Dun', email: 'c@x.y', status: DutyStatus.onBreak),
          ],
          onTap: (e) => tapped = e,
        ),
      ),
    ));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('AL'));
    expect(tapped?.id, '1');
    await tester.pumpWidget(const SizedBox());
  });
}
