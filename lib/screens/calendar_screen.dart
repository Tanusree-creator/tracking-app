import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../models/office_models.dart';
import '../theme/app_theme.dart';
import '../widgets/event_picture.dart';
import '../widgets/glass.dart';
import '../widgets/tn_calendar.dart';

/// Loads everything that happens between [from] and [to] (holidays are added by the screen itself).
typedef CalendarLoader = Future<List<DayItem>> Function(DateTime from, DateTime to);

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Full-screen calendar. Each day shows pictures for holidays, leave, calls, visits and tasks; the admin sees
/// everyone's entries, an employee only their own.
class CalendarScreen extends StatefulWidget {
  final CalendarLoader loader;
  final bool showWho; // admin: say whose entry it is
  final bool embedded; // inside a bottom-nav tab: no back arrow
  const CalendarScreen({super.key, required this.loader, this.showWho = false, this.embedded = false});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selected = _day(DateTime.now());
  final Map<DateTime, List<DayItem>> _byDay = {};
  bool _loading = false;
  String? _error;
  int _dir = 1; // slide direction when changing month

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
    final from = DateTime(_month.year, _month.month - 1, 20);
    final to = DateTime(_month.year, _month.month + 1, 12);
    try {
      final items = await widget.loader(from, to);
      final map = <DateTime, List<DayItem>>{};
      void put(DateTime d, DayItem i) => map.putIfAbsent(_day(d), () => []).add(i);
      for (final y in {from.year, to.year}) {
        for (final h in tnHolidays(y)) {
          put(h.date, DayItem(DayKind.holiday, h.name, h.approx ? 'Public holiday (date may shift by a day)' : 'Public holiday', h.date, approx: h.approx));
        }
      }
      for (final i in items) {
        put(i.at, i); // multi-day leave is already expanded to one item per day by the loaders
      }
      for (final l in map.values) {
        l.sort((a, b) => a.kind.index != b.kind.index && (a.kind == DayKind.holiday || b.kind == DayKind.holiday)
            ? (a.kind == DayKind.holiday ? -1 : 1)
            : a.at.compareTo(b.at));
      }
      if (mounted) {
        setState(() {
          _byDay
            ..clear()
            ..addAll(map);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  void _go(int delta) {
    setState(() {
      _dir = delta;
      _month = DateTime(_month.year, _month.month + delta);
      if (_selected.month != _month.month || _selected.year != _month.year) _selected = DateTime(_month.year, _month.month, 1);
    });
    _load();
  }

  void _today() {
    final n = DateTime.now();
    setState(() {
      _dir = _month.isBefore(DateTime(n.year, n.month)) ? 1 : -1;
      _month = DateTime(n.year, n.month);
      _selected = _day(n);
    });
    _load();
  }

  List<DayItem> _itemsOn(DateTime d) => _byDay[_day(d)] ?? const [];

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? Colors.white : AppColors.blue800;
    final lang = L10n.current.name;
    final monthItems = [
      for (final e in _byDay.entries)
        if (e.key.year == _month.year && e.key.month == _month.month) ...e.value.map((i) => (e.key, i)),
    ]..sort((a, b) => a.$2.at.compareTo(b.$2.at));
    final selItems = _itemsOn(_selected);
    final isToday = _selected == _day(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: widget.embedded ? null : IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).maybePop()),
        title: Text('Calendar'.tr, style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [if (_loading) const Padding(padding: EdgeInsets.only(right: 16), child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))))],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(Sp.l, 0, Sp.l, 48), children: [
        // month header
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(DateFormat('MMMM y', lang).format(_month), style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: ink)),
              ),
              Text(L10n.current == AppLang.ta ? tamilMonthScript(DateTime(_month.year, _month.month, 20)) : '${tamilMonthScript(DateTime(_month.year, _month.month, 20))} · ${tamilMonth(DateTime(_month.year, _month.month, 20)).tr}',
                  style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700)),
            ]),
          ),
          FilledButton(
            onPressed: _today,
            style: FilledButton.styleFrom(minimumSize: const Size(0, 42), padding: const EdgeInsets.symmetric(horizontal: 18), shape: const StadiumBorder()),
            child: Text('Today'.tr, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 8),
          _RoundBtn(Icons.chevron_left, () => _go(-1)),
          const SizedBox(width: 6),
          _RoundBtn(Icons.chevron_right, () => _go(1)),
        ]),
        const SizedBox(height: Sp.l),
        // weekday pills
        Row(children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _WeekPill(i),
              ),
            ),
        ]),
        const SizedBox(height: 8),
        // month grid, slides sideways when the month changes
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, a) {
            final incoming = child.key == ValueKey(_month);
            final begin = Offset(incoming ? .25 * _dir : -.25 * _dir, 0);
            return FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: begin, end: Offset.zero).animate(a), child: child));
          },
          layoutBuilder: (cur, prev) => Stack(alignment: Alignment.topCenter, children: [...prev, ?cur]),
          child: _MonthGrid(
            key: ValueKey(_month),
            month: _month,
            selected: _selected,
            itemsOn: _itemsOn,
            onSelect: (d) => setState(() => _selected = d),
          ),
        ),
        const SizedBox(height: Sp.m),
        // legend
        Wrap(spacing: 14, runSpacing: 6, children: [
          for (final k in DayKind.values)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 18, height: 18, decoration: BoxDecoration(color: Color(k.argb), borderRadius: BorderRadius.circular(6)), child: Icon(k.icon, size: 12, color: Colors.white)),
              const SizedBox(width: 6),
              Text(k.label.tr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
        ]),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: Sp.m), child: Text(_error!.tr, style: const TextStyle(color: AppColors.red))),
        const SizedBox(height: Sp.xl),
        // selected day
        Row(children: [
          Expanded(child: Text(DateFormat('EEEE, d MMMM', lang).format(_selected), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ink))),
          if (isToday) Text('TODAY'.tr, style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: .6)),
        ]),
        const SizedBox(height: Sp.m),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          child: Column(
            key: ValueKey(_selected),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: selItems.isEmpty
                ? [Padding(padding: const EdgeInsets.symmetric(vertical: Sp.s), child: Text('Nothing scheduled on this day.'.tr, style: const TextStyle(color: AppColors.muted)))]
                : [for (final i in selItems) _DayBanner(i, showWho: widget.showWho)],
          ),
        ),
        const SizedBox(height: Sp.l),
        Text('${'Events in'.tr} ${DateFormat('MMMM', lang).format(_month)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ink)),
        const SizedBox(height: Sp.m),
        if (monthItems.isEmpty)
          Text('No events this month.'.tr, style: const TextStyle(color: AppColors.muted))
        else
          for (final (d, i) in monthItems)
            Padding(
              padding: const EdgeInsets.only(bottom: Sp.s),
              child: GlassCard(
                onTap: () => setState(() => _selected = d),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(children: [
                    EventPicture(i, width: 54, height: 54, radius: 14),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_title(i), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                        const SizedBox(height: 2),
                        Text('${DateFormat('EEE, d MMM', lang).format(d)} · ${i.kind.label.tr}${widget.showWho && i.who != null ? ' · ${i.who}' : ''}',
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
        const SizedBox(height: Sp.m),
        Text('Dates marked ≈ follow the moon or the panchangam and can move by a day. Confirm with the official Tamil Nadu Government holiday list.'.tr,
            style: const TextStyle(color: AppColors.muted, fontSize: 11.5)),
      ]),
    );
  }
}

String _title(DayItem i) => switch (i.kind) {
      DayKind.holiday => i.title.tr,
      DayKind.leave => i.who == null ? 'On leave'.tr : '${i.who} ${'on leave'.tr}',
      _ => i.title,
    };

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundBtn(this.icon, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: GlassSurface(radius: 22, blur: 12, child: SizedBox(width: 42, height: 42, child: Icon(icon))),
      );
}

class _WeekPill extends StatelessWidget {
  final int i; // 0 = Monday
  const _WeekPill(this.i);

  static const _tamil = ['திங்கள்', 'செவ்வாய்', 'புதன்', 'வியாழன்', 'வெள்ளி', 'சனி', 'ஞாயிறு'];

  @override
  Widget build(BuildContext context) {
    final sunday = i == 6;
    final lang = L10n.current.name;
    final name = DateFormat('E', lang).format(DateTime(2024, 1, 1 + i)); // 1 Jan 2024 is a Monday
    final fg = sunday ? Colors.white : null;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: sunday ? AppColors.accent : Colors.white.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? .07 : .7),
        border: Border.all(color: sunday ? AppColors.accent : AppColors.edge(Theme.of(context).brightness == Brightness.dark)),
      ),
      child: Column(children: [
        FittedBox(fit: BoxFit.scaleDown, child: Text(name.toUpperCase(), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: fg))),
        if (L10n.current != AppLang.ta)
          FittedBox(fit: BoxFit.scaleDown, child: Text(_tamil[i], style: TextStyle(fontSize: 8.5, color: fg ?? AppColors.muted))),
      ]),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final DateTime selected;
  final List<DayItem> Function(DateTime) itemsOn;
  final ValueChanged<DateTime> onSelect;
  const _MonthGrid({super.key, required this.month, required this.selected, required this.itemsOn, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final start = first.subtract(Duration(days: first.weekday - 1)); // grid starts on Monday
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final weeks = ((first.weekday - 1 + lastDay.day) / 7).ceil();
    final today = _day(DateTime.now());
    return Column(children: [
      for (var w = 0; w < weeks; w++)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            for (var d = 0; d < 7; d++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Builder(builder: (_) {
                    final date = DateTime(start.year, start.month, start.day + w * 7 + d);
                    return _DayCell(
                      date: date,
                      inMonth: date.month == month.month,
                      today: date == today,
                      selected: date == selected,
                      sunday: d == 6,
                      items: itemsOn(date),
                      onTap: () => onSelect(date),
                    );
                  }),
                ),
              ),
          ]),
        ),
    ]);
  }
}

class _DayCell extends StatelessWidget {
  final DateTime date;
  final bool inMonth, today, selected, sunday;
  final List<DayItem> items;
  final VoidCallback onTap;
  const _DayCell({required this.date, required this.inMonth, required this.today, required this.selected, required this.sunday, required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final holiday = items.where((i) => i.kind == DayKind.holiday).firstOrNull;
    final leave = items.where((i) => i.kind == DayKind.leave && i.done).firstOrNull; // approved leave = absent
    final special = holiday != null || sunday;
    final others = items.where((i) => i.kind != DayKind.holiday).toList();
    final main = items.isEmpty ? null : (leave ?? holiday ?? others.first);
    Color text = inMonth ? (special ? AppColors.accent : (dark ? Colors.white : AppColors.blue800)) : AppColors.muted.withValues(alpha: .55);
    if (leave != null && inMonth) text = AppColors.red;

    final BoxDecoration deco;
    if (selected) {
      deco = BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.blue400, AppColors.accent, AppColors.blue800]),
        boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: .4), blurRadius: 12, offset: const Offset(0, 5))],
      );
    } else {
      final tint = leave != null
          ? AppColors.red.withValues(alpha: .13)
          : special
              ? AppColors.accent.withValues(alpha: dark ? .16 : .09)
              : Colors.white.withValues(alpha: dark ? .06 : .72);
      deco = BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: tint,
        border: Border.all(color: leave != null ? AppColors.red.withValues(alpha: .35) : AppColors.edge(dark).withValues(alpha: inMonth ? .8 : .3)),
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        height: 62,
        decoration: deco,
        child: Stack(alignment: Alignment.center, children: [
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: today && !selected ? const BoxDecoration(shape: BoxShape.circle, color: AppColors.accent) : null,
              child: Text('${date.day}', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: selected ? Colors.white : (today ? Colors.white : text))),
            ),
            SizedBox(
              height: 16,
              child: main == null || !inMonth && !selected
                  ? null
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      for (final k in {for (final i in items) i.kind}.take(3))
                        Container(
                          width: 13,
                          height: 13,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(color: Color(k.argb), borderRadius: BorderRadius.circular(4), border: selected ? Border.all(color: Colors.white, width: 1) : null),
                          child: Icon(k == DayKind.holiday ? holidayIcon(holiday?.title ?? '') : k.icon, size: 9, color: Colors.white),
                        ),
                    ]),
            ),
          ]),
          if (items.length > 1 && inMonth)
            Positioned(
              top: 3,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: const Color(0xFF7C4DFF), borderRadius: BorderRadius.circular(9)),
                child: Text('${items.length}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
              ),
            ),
        ]),
      ),
    );
  }
}

/// The big picture card for one entry of the selected day.
class _DayBanner extends StatelessWidget {
  final DayItem item;
  final bool showWho;
  const _DayBanner(this.item, {required this.showWho});

  @override
  Widget build(BuildContext context) {
    final lang = L10n.current.name;
    final title = _title(item);
    final kindLabel = item.kind == DayKind.leave && item.done ? 'Absent (leave approved)' : item.kind.label;
    final color = Color(item.kind.argb);
    final details = [
      if (item.subtitle.isNotEmpty) item.subtitle.tr,
      if (item.kind != DayKind.holiday && item.kind != DayKind.leave) DateFormat('h:mm a', lang).format(item.at),
      if (showWho && item.who != null) item.who!,
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.m),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        EventPicture(
          item,
          height: 168,
          radius: 24,
          overlay: Stack(children: [
            Positioned(
              left: 14,
              top: 14,
              child: Container(
                width: 60,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: Column(children: [
                  Text(DateFormat('MMM', lang).format(item.at).toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11)),
                  Text('${item.at.day}', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w800, fontSize: 24, height: 1.1)),
                ]),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: .92), borderRadius: BorderRadius.circular(22)),
                child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w800, fontSize: 17)),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: color.withValues(alpha: .14), borderRadius: BorderRadius.circular(20)),
          child: Text(kindLabel.tr.toUpperCase(),
              style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11.5, letterSpacing: .5)),
        ),
        if (details.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(details, style: const TextStyle(fontSize: 14.5))),
      ]),
    );
  }
}
