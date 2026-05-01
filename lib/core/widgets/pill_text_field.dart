import 'package:flutter/material.dart';

class PillTextField extends StatefulWidget {
  const PillTextField({
    super.key,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.obscureText = false,
    this.textAlign = TextAlign.start,
    this.maxLength,
    this.maxWidth = 520,
  });

  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final bool obscureText;
  final TextAlign textAlign;
  final int? maxLength;
  final double? maxWidth;

  @override
  State<PillTextField> createState() => _PillTextFieldState();
}

class _PillTextFieldState extends State<PillTextField> {
  late bool _obscure;

  @override
  void initState() {
    super.initState();
    _obscure = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: widget.maxWidth ?? double.infinity,
        ),
        child: SizedBox(
          height: 56,
          child: TextField(
            controller: widget.controller,
            keyboardType: widget.keyboardType,
            obscureText: _obscure,
            textAlign: widget.textAlign,
            maxLength: widget.maxLength,
            textAlignVertical: TextAlignVertical.center,
            style: const TextStyle(fontSize: 17, height: 1.25),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              counterText: '',
              hintText: widget.hint,
              hintStyle: const TextStyle(
                color: Color(0xFF6B6176),
                fontSize: 16,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              suffixIcon:
                  widget.obscureText
                      ? IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 19,
                          color: const Color(0xFF625B71),
                        ),
                        tooltip: _obscure ? 'Show password' : 'Hide password',
                      )
                      : null,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFD9D2E2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF1D1B20),
                  width: 1.4,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFB3261E)),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFFB3261E),
                  width: 1.4,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
