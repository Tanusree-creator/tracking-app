import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackingapp/l10n/l10n.dart';
import 'package:trackingapp/models/office_models.dart';
import 'package:trackingapp/screens/calendar_screen.dart';
import 'package:trackingapp/theme/app_theme.dart';
import 'package:trackingapp/widgets/anim.dart';

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    return initializeDateFormatting();
  });
  tearDown(() => L10n.current = AppLang.en);

  test('translations, patterns and fallbacks', () {
    L10n.current = AppLang.hi;
    expect('Home'.tr, 'होम');
    expect('Message from Asha'.tr, 'Asha का संदेश');
    expect('Could not save: Network error. Check your connection.'.tr, startsWith('सहेज नहीं सके: '));
    expect('Some unknown text'.tr, 'Some unknown text'); // falls back to English
    expect(trf('Hi, {}', ['Ravi']), 'नमस्ते, Ravi');
    L10n.current = AppLang.ta;
    expect('Home'.tr, 'முகப்பு');
    expect('Ravi closed a task'.tr, 'Ravi ஒரு பணியை முடித்தார்');
    expect(trCount(2, 'task', 'tasks'), '2 பணிகள்');
  });

  testWidgets('calendar shows holidays, leave and switches language', (tester) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final today = DateTime.now();
    final l10n = L10n();
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: l10n,
      child: Consumer<L10n>(
        builder: (_, l, _) => MaterialApp(
          locale: l.lang.locale,
          supportedLocales: [for (final x in AppLang.values) x.locale],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: buildTheme(Brightness.light),
          home: CalendarScreen(
            showWho: true,
            loader: (from, to) async => [
              DayItem(DayKind.leave, 'On leave', 'Approved', DateTime(today.year, today.month, today.day), done: true, who: 'Asha'),
              DayItem(DayKind.call, 'Raj School', 'Order books', DateTime(today.year, today.month, today.day, 11), who: 'Asha'),
            ],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Calendar'), findsOneWidget);
    expect(find.textContaining('Asha on leave'), findsWidgets);
    expect(tester.takeException(), isNull);

    await l10n.set(AppLang.ta);
    await tester.pumpAndSettle();
    expect(find.text('நாட்காட்டி'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tab stack keeps pages and animates', (tester) async {
    var index = 0;
    late StateSetter set;
    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(builder: (_, s) {
        set = s;
        return AnimatedTabStack(index: index, children: const [Text('one'), Text('two')]);
      }),
    ));
    expect(find.text('one'), findsOneWidget);
    expect(find.text('two'), findsNothing); // built lazily
    set(() => index = 1);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('two'), findsOneWidget);
    await tester.pumpAndSettle();
    set(() => index = 0);
    await tester.pumpAndSettle();
    expect(find.text('one'), findsOneWidget);
  });
}
