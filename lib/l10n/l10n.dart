import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'strings_hi.dart';
import 'strings_ta.dart';

enum AppLang {
  en('English', 'English'),
  hi('हिन्दी', 'Hindi'),
  ta('தமிழ்', 'Tamil');

  final String native;
  final String english;
  const AppLang(this.native, this.english);

  Locale get locale => Locale(name);
}

/// App language. Text is written in English in the code and looked up with `'Home'.tr`;
/// anything missing from a language falls back to the English text.
class L10n extends ChangeNotifier {
  static AppLang current = AppLang.en;

  AppLang get lang => current;

  static final _compiled = <Map<String, String>, List<(RegExp, String)>>{};

  /// Entries whose key has `{}` placeholders ("Message from {}") match any text in that shape.
  static List<(RegExp, String)> _patterns(Map<String, String> map) => _compiled.putIfAbsent(map, () => [
        for (final e in map.entries)
          if (e.key.contains('{}'))
            (RegExp('^${e.key.split('{}').map(RegExp.escape).join('(.+?)')}\$', dotAll: true), e.value),
      ]);

  static String t(String s) {
    if (current == AppLang.en || s.isEmpty) return s;
    final map = current == AppLang.hi ? stringsHi : stringsTa;
    final hit = map[s];
    if (hit != null) return hit;
    for (final (re, tpl) in _patterns(map)) {
      final m = re.firstMatch(s);
      if (m == null) continue;
      var i = 0;
      return tpl.replaceAllMapped('{}', (_) => i < m.groupCount ? (map[m.group(++i)!] ?? m.group(i)!) : '');
    }
    // "Could not save: <reason>": translate each side of the first colon.
    final i = s.indexOf(': ');
    if (i > 0 && i < 48) {
      final head = map[s.substring(0, i)];
      if (head != null) return '$head: ${t(s.substring(i + 2))}';
    }
    return s;
  }

  /// Template with `{}` placeholders: `trf('Hi, {}', [name])`.
  static String f(String template, List<Object?> args) {
    var i = 0;
    return t(template).replaceAllMapped('{}', (_) => i < args.length ? '${args[i++]}' : '');
  }

  Future<void> load() async {
    try {
      await initializeDateFormatting();
      final saved = (await SharedPreferences.getInstance()).getString('lang');
      current = AppLang.values.firstWhere((l) => l.name == saved, orElse: () => AppLang.en);
    } catch (_) {}
    Intl.defaultLocale = current.name;
  }

  Future<void> set(AppLang l) async {
    if (l == current) return;
    current = l;
    Intl.defaultLocale = l.name;
    notifyListeners();
    _rebuildEverything();
    _save(l);
  }

  Future<void> _save(AppLang l) async {
    try {
      (await SharedPreferences.getInstance()).setString('lang', l.name);
    } catch (_) {}
  }

  /// Text is translated without a BuildContext, so widgets that were built earlier (including `const` ones)
  /// need a nudge to look their strings up again.
  void _rebuildEverything() {
    void visit(Element e) {
      e.markNeedsBuild();
      e.visitChildren(visit);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => WidgetsBinding.instance.rootElement?.visitChildren(visit));
    WidgetsBinding.instance.scheduleFrame();
  }
}

extension Tr on String {
  String get tr => L10n.t(this);
}

/// `trf('Hi, {}', [name])`: translate the template, then fill the blanks.
String trf(String template, List<Object?> args) => L10n.f(template, args);

/// "3 tasks", "1 task" etc. Digits stay the same in every language.
String trCount(int n, String one, String many) => '$n ${(n == 1 ? one : many).tr}';
