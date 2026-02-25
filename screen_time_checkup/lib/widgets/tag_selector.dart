import 'package:flutter/material.dart';

class TagSelector extends StatelessWidget {
  final String label;
  final String? selectedTag;
  final List<String> availableTags;
  final void Function(String?) onChanged;

  const TagSelector({
    super.key,
    required this.label,
    required this.selectedTag,
    required this.availableTags,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).dividerColor,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedTag,
              hint: const Text('Select a tag'),
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down, size: 30),
              items: availableTags.isEmpty
                  ? [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('No tags available - add in Settings'),
                      ),
                    ]
                  : availableTags.map((tag) {
                      return DropdownMenuItem<String>(
                        value: tag,
                        child: Text(tag),
                      );
                    }).toList(),
              onChanged: availableTags.isEmpty ? null : onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
