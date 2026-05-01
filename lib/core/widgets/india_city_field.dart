import 'package:flutter/material.dart';

import '../constants/india_cities.dart';

class IndiaCityField extends StatefulWidget {
  const IndiaCityField({
    super.key,
    required this.controller,
    this.hint,
    this.textAlign = TextAlign.start,
    this.fillColor,
    this.borderRadius = 12,
    this.onChanged,
  });

  final TextEditingController controller;
  final String? hint;
  final TextAlign textAlign;
  final Color? fillColor;
  final double borderRadius;
  final ValueChanged<String>? onChanged;

  @override
  State<IndiaCityField> createState() => _IndiaCityFieldState();
}

class _IndiaCityFieldState extends State<IndiaCityField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      optionsBuilder: (value) {
        final query = value.text.trim().toLowerCase();
        if (query.isEmpty) return indiaCities.take(20);
        return indiaCities
            .where((city) => city.toLowerCase().contains(query))
            .take(20);
      },
      onSelected: (city) {
        widget.controller.text = city;
        widget.onChanged?.call(city);
      },
      fieldViewBuilder: (context, fieldController, focusNode, onSubmitted) {
        return SizedBox(
          height: 56,
          child: TextField(
            controller: fieldController,
            focusNode: focusNode,
            textAlign: widget.textAlign,
            textAlignVertical: TextAlignVertical.center,
            textInputAction: TextInputAction.next,
            onChanged: widget.onChanged,
            style: const TextStyle(fontSize: 17, height: 1.25),
            decoration: InputDecoration(
              isDense: true,
              hintText: widget.hint,
              hintStyle: const TextStyle(
                color: Color(0xFF6B6176),
                fontSize: 16,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              filled: true,
              fillColor: widget.fillColor ?? Colors.white,
              suffixIcon: const Icon(
                Icons.keyboard_arrow_down,
                color: Color(0xFF625B71),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                borderSide: const BorderSide(color: Color(0xFFD9D2E2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                borderSide: const BorderSide(
                  color: Color(0xFF1D1B20),
                  width: 1.5,
                ),
              ),
            ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(14),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, maxWidth: 360),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final city = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(city, overflow: TextOverflow.ellipsis),
                    onTap: () => onSelected(city),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
