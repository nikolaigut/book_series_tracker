import 'package:flutter/material.dart';

import '../models/series.dart';

class AddToSeriesDialog extends StatefulWidget {
  final String? initialName;
  final String? initialAuthor;
  final List<ReadingSeries> existingSeries;

  const AddToSeriesDialog({
    super.key,
    this.initialName,
    this.initialAuthor,
    required this.existingSeries,
  });

  @override
  State<AddToSeriesDialog> createState() => _AddToSeriesDialogState();
}

class _AddToSeriesDialogState extends State<AddToSeriesDialog> {
  int? _selectedSeriesId;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _authorController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.initialName ?? '';
    _authorController.text = widget.initialAuthor ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Zur Reihe hinzufügen'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.existingSeries.isNotEmpty) ...[
              const Text('Bestehende Reihe'),
              DropdownButtonFormField<int?>(
                initialValue: _selectedSeriesId,
                isExpanded: true,
                hint: const Text('Reihe auswählen'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('-- Neue Reihe --')),
                  ...widget.existingSeries.map(
                    (s) => DropdownMenuItem(value: s.id, child: Text(s.name)),
                  ),
                ],
                onChanged: (value) {
                  setState(() => _selectedSeriesId = value);
                },
              ),
              const SizedBox(height: 16),
            ],
            if (_selectedSeriesId == null || widget.existingSeries.isEmpty) ...[
              const Text('Neue Reihe'),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name der Reihe'),
              ),
              TextField(
                controller: _authorController,
                decoration: const InputDecoration(labelText: 'Autor (optional)'),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () {
            if (_selectedSeriesId == null && _nameController.text.trim().isEmpty) {
              return;
            }
            final series = _selectedSeriesId != null
                ? widget.existingSeries.firstWhere((s) => s.id == _selectedSeriesId)
                : ReadingSeries(
                    name: _nameController.text.trim(),
                    author: _authorController.text.trim().isEmpty
                        ? null
                        : _authorController.text.trim(),
                    createdAt: DateTime.now(),
                  );
            Navigator.of(context).pop(series);
          },
          child: const Text('Hinzufügen'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _authorController.dispose();
    super.dispose();
  }
}
