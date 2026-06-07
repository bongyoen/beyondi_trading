import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../shared/theme/font_helper.dart';

/// Common input field - reusable, accessible, modern.
class CommonInputField extends StatelessWidget {
  const CommonInputField({
    super.key,
    required this.label,
    required this.hint,
    this.controller,
    this.obscureText = false,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.focusNode,
    this.autofocus = false,
    this.maxLines = 1,
    this.keyboardType,
    this.onChanged,
    this.validator,
    this.enableInteractiveSelection = true,
    this.inputFormatters,
    this.prefixText,
    this.isDense = false,
  });

  final String label;
  final String hint;
  final TextEditingController? controller;
  final bool obscureText;
  final String? errorText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final TextInputAction textInputAction;
  final void Function(String)? onSubmitted;
  final FocusNode? focusNode;
  final bool autofocus;
  final int maxLines;
  final TextInputType? keyboardType;
  final void Function(String)? onChanged;
  final String? Function(String?)? validator;
  final bool enableInteractiveSelection;
  final List<TextInputFormatter>? inputFormatters;
  final String? prefixText;
  final bool isDense;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasError = errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              label,
              style: inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: hasError ? colorScheme.error : colorScheme.onSurface,
              ),
            ),
          ),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          autofocus: autofocus,
          maxLines: maxLines,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          enableInteractiveSelection: enableInteractiveSelection,
          inputFormatters: inputFormatters,
          onFieldSubmitted: onSubmitted != null
              ? (v) => onSubmitted!(v)
              : (_) => FocusScope.of(context).nextFocus(),
          onChanged: onChanged,
          validator: validator,
          style: inter(fontSize: isDense ? 13 : 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: inter(
              fontSize: isDense ? 12 : 14,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, size: 20)
                : null,
            prefixText: prefixText,
            suffixIcon: suffixIcon,
            errorText: errorText,
            isDense: isDense,
            contentPadding: isDense
                ? const EdgeInsets.symmetric(horizontal: 8, vertical: 6)
                : const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isDense ? 6 : 10),
            ),
          ),
        ),
      ],
    );
  }
}
