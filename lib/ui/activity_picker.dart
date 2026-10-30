import 'package:flutter/material.dart';

import '../domain/models.dart';
import 'format.dart';

/// Диалог выбора вида нагрузки: поиск + фильтр по категории.
class ActivityPickerDialog extends StatefulWidget {
  final Catalog catalog;
  final Activity? selected;

  const ActivityPickerDialog({super.key, required this.catalog, this.selected});

  static Future<Activity?> show(BuildContext context, Catalog catalog, Activity? selected) =>
      showDialog<Activity>(
        context: context,
        builder: (_) => ActivityPickerDialog(catalog: catalog, selected: selected),
      );

  @override
  State<ActivityPickerDialog> createState() => _ActivityPickerDialogState();
}

class _ActivityPickerDialogState extends State<ActivityPickerDialog> {
  String _query = '';
  int? _categoryId;

  late final Map<int, String> _categoryNames = {
    for (final c in widget.catalog.activityCategories) c.id: c.nameRu,
  };

  @override
  void initState() {
    super.initState();
    _categoryId = widget.selected?.categoryId;
  }

  List<Activity> get _filtered {
    final q = _query.toLowerCase();
    return widget.catalog.activities.where((a) {
      if (_categoryId != null && a.categoryId != _categoryId) return false;
      if (q.isEmpty) return true;
      return a.nameEn.toLowerCase().contains(q) ||
          (a.nameRu?.toLowerCase().contains(q) ?? false) ||
          a.code.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    return AlertDialog(
      title: const Text('Вид нагрузки'),
      content: SizedBox(
        width: 640,
        height: 520,
        child: Column(children: [
          TextField(
            autofocus: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Поиск (например, бег, гребля, running или код 02074)',
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int?>(
            initialValue: _categoryId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Категория'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Все категории')),
              for (final c in widget.catalog.activityCategories)
                DropdownMenuItem(value: c.id, child: Text(c.nameRu)),
            ],
            onChanged: (v) => setState(() => _categoryId = v),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Найдено: ${items.length}', style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, i) {
                final a = items[i];
                return ListTile(
                  dense: true,
                  selected: a.code == widget.selected?.code,
                  title: Text(a.displayName),
                  subtitle: Text('${_categoryNames[a.categoryId]} · MET ${fmt(a.met, 1)}'),
                  onTap: () => Navigator.pop(context, a),
                );
              },
            ),
          ),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена'))],
    );
  }
}
