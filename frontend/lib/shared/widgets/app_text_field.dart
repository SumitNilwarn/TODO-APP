import 'package:flutter/material.dart';

/// Application text input built on `TextField` with consistent decoration.
///
/// Labels, hints, errors, prefix/suffix icons and focus styling all come from
/// the theme's `InputDecorationTheme`; feature forms reuse this without
/// re-declaring input geometry.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.label,
    this.hintText,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.suffix,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autocorrect = true,
    this.textCapitalization = TextCapitalization.none,
    this.enabled = true,
    this.maxLength,
    this.maxLines = 1,
    this.minLines,
    this.onChanged,
    this.onSubmitted,
    this.semanticsLabel,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;

  /// Visible field label (also used by screen readers).
  final String? label;
  final String? hintText;
  final String? helperText;

  /// Inline validation message, rendered in the error color.
  final String? errorText;

  final IconData? prefixIcon;
  final IconData? suffixIcon;

  /// Optional trailing widget (e.g. a dynamic clear button). Takes precedence
  /// over [suffixIcon] when both are provided.
  final Widget? suffix;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool autocorrect;
  final TextCapitalization textCapitalization;
  final bool enabled;
  final int? maxLength;
  final int maxLines;
  final int? minLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// Overrides the label announced by screen readers. When `null` the visible
  /// [label] (or input content) is announced.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autocorrect: autocorrect,
      textCapitalization: textCapitalization,
      maxLength: maxLength,
      maxLines: maxLines,
      minLines: minLines,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        helperText: helperText,
        errorText: errorText,
        counterText: '',
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
        suffixIcon: suffix ?? (suffixIcon == null ? null : Icon(suffixIcon)),
      ),
    );

    if (semanticsLabel == null) return field;
    return Semantics(label: semanticsLabel, child: field);
  }
}
