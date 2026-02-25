import 'package:flutter/material.dart';
import 'package:textfield_tags/textfield_tags.dart';

class TagInput extends StatefulWidget {
  final List<String> initialTags;
  final void Function(List<String> tags) onTagsChanged;

  const TagInput({
    super.key,
    required this.initialTags,
    required this.onTagsChanged,
  });

  @override
  State<TagInput> createState() => _TagInputState();
}

class _TagInputState extends State<TagInput> {
  late StringTagController _tagController;

  @override
  void initState() {
    super.initState();
    _tagController = StringTagController();
  }

  @override
  void dispose() {
    _tagController.dispose();
    super.dispose();
  }

  void _addTag(InputFieldValues<String> inputFieldValues) {
    final val = inputFieldValues.textEditingController.text;
    final trimmed = val.trim();
    final isDuplicate = inputFieldValues.tags
        .any((tag) => tag.toLowerCase() == trimmed.toLowerCase());
    if (trimmed.isNotEmpty && !isDuplicate) {
      inputFieldValues.onTagSubmitted(trimmed);
      widget.onTagsChanged(inputFieldValues.tags);
    } else {
      inputFieldValues.textEditingController.clear();
    }
    inputFieldValues.focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final chipBgColor = Theme.of(context).colorScheme.secondaryContainer;
    final chipTextColor = Theme.of(context).colorScheme.onSecondaryContainer;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFieldTags<String>(
        textfieldTagsController: _tagController,
        initialTags: widget.initialTags,
        textSeparators: const [','],
        inputFieldBuilder: (context, inputFieldValues) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (inputFieldValues.tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: inputFieldValues.tags.map((tag) {
                      return Chip(
                        label: Text(tag),
                        labelStyle: TextStyle(color: chipTextColor),
                        backgroundColor: chipBgColor,
                        deleteIconColor: chipTextColor,
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                        onDeleted: () {
                          inputFieldValues.onTagRemoved(tag);
                          widget.onTagsChanged(inputFieldValues.tags);
                        },
                      );
                    }).toList(),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: inputFieldValues.textEditingController,
                      focusNode: inputFieldValues.focusNode,
                      onChanged: inputFieldValues.onTagChanged,
                      onSubmitted: (_) => _addTag(inputFieldValues),
                      decoration: const InputDecoration(
                        hintText: 'Add tags...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => _addTag(inputFieldValues),
                    child: const Text('Add Tag'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
