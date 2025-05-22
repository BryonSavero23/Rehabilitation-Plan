import 'package:flutter/material.dart';

class EnhancedDropdown extends StatefulWidget {
  final String label;
  final List<String> items;
  final String value;
  final Function(String) onChanged;
  final String? otherValue;
  final Function(String) onOtherChanged;
  final String? otherHintText;
  final bool isRequired;

  const EnhancedDropdown({
    Key? key,
    required this.label,
    required this.items,
    required this.value,
    required this.onChanged,
    this.otherValue,
    required this.onOtherChanged,
    this.otherHintText,
    this.isRequired = false,
  }) : super(key: key);

  @override
  State<EnhancedDropdown> createState() => _EnhancedDropdownState();
}

class _EnhancedDropdownState extends State<EnhancedDropdown> {
  late List<String> _itemsWithOther;
  late TextEditingController _otherController;

  @override
  void initState() {
    super.initState();
    _otherController = TextEditingController(text: widget.otherValue);
    _updateItemsList();
  }

  @override
  void didUpdateWidget(EnhancedDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items != oldWidget.items) {
      _updateItemsList();
    }
    if (widget.otherValue != oldWidget.otherValue) {
      _otherController.text = widget.otherValue ?? '';
    }
  }

  void _updateItemsList() {
    _itemsWithOther = List.from(widget.items);
    if (!_itemsWithOther.contains('Other')) {
      _itemsWithOther.add('Other');
    }
  }

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
            labelText: widget.label,
            labelStyle: TextStyle(
              color: Colors.grey[700],
              fontSize: 16,
            ),
          ),
          value: widget.value,
          items: _itemsWithOther.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              widget.onChanged(value);
            }
          },
          validator: widget.isRequired
              ? (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a value';
                  }
                  return null;
                }
              : null,
        ),
        if (widget.value == 'Other')
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 16.0),
            child: TextFormField(
              controller: _otherController,
              decoration: InputDecoration(
                labelText: 'Specify Other',
                hintText: widget.otherHintText ?? 'Please specify',
                isDense: true,
              ),
              onChanged: widget.onOtherChanged,
              validator: (value) {
                if (widget.value == 'Other' &&
                    (value == null || value.isEmpty)) {
                  return 'Please specify your other selection';
                }
                return null;
              },
            ),
          ),
      ],
    );
  }
}
