import 'package:flutter/material.dart';

class SectionConfig {
  final String id;
  final String label;

  const SectionConfig({required this.id, required this.label});
}

void showPageCustomizationSheet({
  required BuildContext context,
  required String pageTitle,
  required List<SectionConfig> allSections,
  required List<String> currentOrder,
  required List<String> hiddenSections,
  required void Function(List<String> order, List<String> hidden) onChanged,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => _PageCustomizationSheet(
      pageTitle: pageTitle,
      allSections: allSections,
      currentOrder: currentOrder,
      hiddenSections: hiddenSections,
      onChanged: onChanged,
    ),
  );
}

class _PageCustomizationSheet extends StatefulWidget {
  final String pageTitle;
  final List<SectionConfig> allSections;
  final List<String> currentOrder;
  final List<String> hiddenSections;
  final void Function(List<String> order, List<String> hidden) onChanged;

  const _PageCustomizationSheet({
    required this.pageTitle,
    required this.allSections,
    required this.currentOrder,
    required this.hiddenSections,
    required this.onChanged,
  });

  @override
  State<_PageCustomizationSheet> createState() => _PageCustomizationSheetState();
}

class _PageCustomizationSheetState extends State<_PageCustomizationSheet> {
  late List<String> _order;
  late Set<String> _hidden;

  @override
  void initState() {
    super.initState();
    // Ensure order contains all section IDs (add any missing ones at the end)
    final allIds = widget.allSections.map((s) => s.id).toSet();
    _order = List<String>.from(widget.currentOrder);
    for (final id in allIds) {
      if (!_order.contains(id)) {
        _order.add(id);
      }
    }
    // Remove any IDs from order that are no longer valid sections
    _order.removeWhere((id) => !allIds.contains(id));
    _hidden = Set<String>.from(widget.hiddenSections);
  }

  void _notifyChanged() {
    widget.onChanged(List<String>.from(_order), _hidden.toList());
  }

  void _resetToDefaults() {
    setState(() {
      _order = widget.allSections.map((s) => s.id).toList();
      _hidden.clear();
    });
    _notifyChanged();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle bar
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Customize ${widget.pageTitle}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _resetToDefaults,
                    child: const Text('Reset to defaults'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Reorderable list
            Expanded(
              child: ReorderableListView(
                scrollController: scrollController,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = _order.removeAt(oldIndex);
                    _order.insert(newIndex, item);
                  });
                  _notifyChanged();
                },
                children: _order.map((id) {
                  final section = widget.allSections.firstWhere(
                    (s) => s.id == id,
                    orElse: () => SectionConfig(id: id, label: id),
                  );
                  final isVisible = !_hidden.contains(id);

                  return ListTile(
                    key: ValueKey(id),
                    leading: ReorderableDragStartListener(
                      index: _order.indexOf(id),
                      child: const Icon(Icons.drag_handle),
                    ),
                    title: Text(
                      section.label,
                      style: TextStyle(
                        color: isVisible
                            ? colorScheme.onSurface
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: Switch(
                      value: isVisible,
                      onChanged: (value) {
                        setState(() {
                          if (value) {
                            _hidden.remove(id);
                          } else {
                            _hidden.add(id);
                          }
                        });
                        _notifyChanged();
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}
