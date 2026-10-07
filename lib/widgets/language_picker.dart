import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../theme/app_theme.dart';

/// Bottom sheet with the three app languages. The whole app switches as soon as one is tapped.
Future<void> showLanguageSheet(BuildContext context) => showModalBottomSheet(
      context: context,
      builder: (_) => const _LanguageSheet(),
    );

class _LanguageSheet extends StatelessWidget {
  const _LanguageSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<L10n>();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Sp.l, 0, Sp.l, Sp.l),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('App language'.tr, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('The whole app changes to the language you pick.'.tr, style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: Sp.m),
          for (final l in AppLang.values)
            Padding(
              padding: const EdgeInsets.only(bottom: Sp.s),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: l == l10n.lang ? AppColors.accent : AppColors.edge(Theme.of(context).brightness == Brightness.dark), width: l == l10n.lang ? 1.8 : 1),
                ),
                tileColor: l == l10n.lang ? AppColors.accent.withValues(alpha: .1) : null,
                title: Text(l.native, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                subtitle: Text(l.english),
                trailing: l == l10n.lang ? const Icon(Icons.check_circle, color: AppColors.accent) : null,
                onTap: () async {
                  await context.read<L10n>().set(l);
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
            ),
        ]),
      ),
    );
  }
}

/// Settings row that shows the current language and opens the picker.
class LanguageTile extends StatelessWidget {
  const LanguageTile({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<L10n>().lang;
    return ListTile(
      leading: const Icon(Icons.translate),
      title: Text('Language'.tr),
      subtitle: Text('${lang.native} · ${lang.english}'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showLanguageSheet(context),
    );
  }
}

/// Compact button for app bars and the sign-in page.
class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Language'.tr,
        icon: const Icon(Icons.translate),
        onPressed: () => showLanguageSheet(context),
      );
}
