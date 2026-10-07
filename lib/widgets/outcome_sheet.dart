import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import 'glass.dart';

class VisitResult {
  final VisitOutcome outcome;
  final String? note;
  final int? copies;
  const VisitResult(this.outcome, this.note, this.copies);
}

/// Asks how the visit went. Returns null if dismissed (the visit then stays open).
Future<VisitResult?> askVisitOutcome(BuildContext context) => showModalBottomSheet<VisitResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _OutcomeSheet(),
    );

class _OutcomeSheet extends StatefulWidget {
  const _OutcomeSheet();

  @override
  State<_OutcomeSheet> createState() => _OutcomeSheetState();
}

class _OutcomeSheetState extends State<_OutcomeSheet> {
  VisitOutcome? _pick;
  final _copies = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _copies.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('How did the visit go?', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Your admin sees this when the task is closed.', style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final o in VisitOutcome.values)
              ChoiceChip(
                avatar: Icon(o.icon, size: 18, color: _pick == o ? Colors.white : AppColors.accent),
                label: Text(o.label),
                selected: _pick == o,
                selectedColor: AppColors.accent,
                labelStyle: TextStyle(color: _pick == o ? Colors.white : null, fontWeight: FontWeight.w600),
                showCheckmark: false,
                onSelected: (_) => setState(() => _pick = o),
              ),
          ]),
          if (_pick?.hasCopies == true) ...[
            const SizedBox(height: 12),
            GlowTextField(
              controller: _copies,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: _pick == VisitOutcome.ordered ? 'Copies ordered' : 'Copies given', prefixIcon: const Icon(Icons.numbers)),
            ),
          ],
          const SizedBox(height: 12),
          GlowTextField(
            controller: _note,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Note (optional)', hintText: 'Who you met, titles they liked...', prefixIcon: Icon(Icons.edit_note)),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _pick == null
                ? null
                : () => Navigator.pop(context, VisitResult(_pick!, _note.text.trim().isEmpty ? null : _note.text.trim(), _pick!.hasCopies ? int.tryParse(_copies.text.trim()) : null)),
            child: const Text('Close task'),
          ),
        ]),
      );
}
