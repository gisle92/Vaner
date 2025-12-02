import 'package:flutter/material.dart';

import '../habit_suggestions.dart';

/// Result returned from the add habit dialog.
class NewHabitResult {
  final String name;
  final String categoryId;
  final int? targetDays;

  NewHabitResult({
    required this.name,
    required this.categoryId,
    required this.targetDays,
  });
}

/// Add-habit dialog: categories + suggestions + optional duration
class NewHabitDialog extends StatefulWidget {
  const NewHabitDialog();

  @override
  State<NewHabitDialog> createState() => _NewHabitDialogState();
}

class _NewHabitDialogState extends State<NewHabitDialog> {
  late String _selectedCategoryId;
  final TextEditingController _controller = TextEditingController();
  int? _targetDays;

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = habitCategories.first.id;
    _targetDays = null; // no goal by default
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _selectSuggestion(String text) {
    setState(() {
      _controller.text = text;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: text.length),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final suggestions =
        habitSuggestions[_selectedCategoryId] ?? const <String>[];
    final durationOptions = <int?>[null, 14, 30, 60, 90];

    return AlertDialog(
      title: const Text('Ny vane'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Velg kategori',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: habitCategories.map((cat) {
                final selected = cat.id == _selectedCategoryId;
                return ChoiceChip(
                  label: Text('${cat.emoji} ${cat.label}'),
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      _selectedCategoryId = cat.id;
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            if (suggestions.isNotEmpty) ...[
              const Text(
                'Forslag',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: suggestions.map((s) {
                  return ActionChip(
                    label: Text(s),
                    onPressed: () => _selectSuggestion(s),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
            const Text(
              'Varighet (valgfritt)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: durationOptions.map((value) {
                final selected = _targetDays == value;
                String label;
                if (value == null) {
                  label = 'Ingen mål';
                } else {
                  label = '$value dager';
                }
                return ChoiceChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      _targetDays = value;
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text(
              'Eller skriv din egen',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'f.eks. 10 push-ups',
              ),
              autofocus: true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Avbryt'),
        ),
        FilledButton(
          onPressed: () {
            final text = _controller.text.trim();
            if (text.isNotEmpty) {
              Navigator.of(context).pop(
                NewHabitResult(
                  name: text,
                  categoryId: _selectedCategoryId,
                  targetDays: _targetDays,
                ),
              );
            }
          },
          child: const Text('Lagre'),
        ),
      ],
    );
  }
}
