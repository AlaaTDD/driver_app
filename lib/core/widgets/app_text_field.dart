import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:snapix/core/theme/theme_extensions.dart';

/// Enhanced text field that covers all use cases found across the app:
/// - Password visibility toggle (showPasswordToggle)
/// - Enabled/disabled states
/// - initialValue & autovalidateMode
/// - autofillHints & textCapitalization
/// - prefixText (e.g. "+966")
/// - Multiline with expands / minLines / maxLines
/// - onEditingComplete / onFieldSubmitted
class AppTextField extends StatefulWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final bool obscureText;
  final bool readOnly;
  final bool enabled;
  final bool showPasswordToggle;
  final IconData? prefixIcon;
  final Widget? suffix;
  final Widget? prefixWidget;
  final String? prefixText;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final int? minLines;
  final bool expands;
  final VoidCallback? onTap;
  final void Function(String)? onChanged;
  final VoidCallback? onEditingComplete;
  final void Function(String)? onFieldSubmitted;
  final FocusNode? focusNode;
  final TextInputAction textInputAction;
  final AutovalidateMode autovalidateMode;
  final String? initialValue;
  final List<String>? autofillHints;
  final TextCapitalization textCapitalization;
  final String? counterText;
  final int? maxLength;
  final bool autofocus;

  const AppTextField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.readOnly = false,
    this.enabled = true,
    this.showPasswordToggle = false,
    this.prefixIcon,
    this.suffix,
    this.prefixWidget,
    this.prefixText,
    this.inputFormatters,
    this.maxLines = 1,
    this.minLines,
    this.expands = false,
    this.onTap,
    this.onChanged,
    this.onEditingComplete,
    this.onFieldSubmitted,
    this.focusNode,
    this.textInputAction = TextInputAction.next,
    this.autovalidateMode = AutovalidateMode.disabled,
    this.initialValue,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
    this.counterText,
    this.maxLength,
    this.autofocus = false,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscure;

  @override
  void initState() {
    super.initState();
    _obscure = widget.obscureText || widget.showPasswordToggle;
  }

  Widget? get _resolvedSuffix {
    if (widget.showPasswordToggle) {
      return IconButton(
        onPressed: () => setState(() => _obscure = !_obscure),
        icon: Icon(
          _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
          size: 20,
          color: widget.enabled
              ? const Color(0xFF7B82A3) // AppColors.textSecondary
              : const Color(0xFF3A4060), // AppColors.textDisabled
        ),
      );
    }
    return widget.suffix;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: TextStyle(
              color: widget.enabled
                  ? context.textSecondary
                  : context.textDisabled,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: widget.controller,
          initialValue: widget.initialValue,
          validator: widget.validator,
          autovalidateMode: widget.autovalidateMode,
          keyboardType: widget.keyboardType,
          obscureText: _obscure,
          readOnly: widget.readOnly,
          enabled: widget.enabled,
          inputFormatters: widget.inputFormatters,
          maxLines: widget.expands
              ? null
              : (widget.obscureText || widget.showPasswordToggle
                  ? 1
                  : widget.maxLines),
          minLines: widget.minLines,
          expands: widget.expands,
          onTap: widget.onTap,
          onChanged: widget.onChanged,
          onEditingComplete: widget.onEditingComplete,
          onFieldSubmitted: widget.onFieldSubmitted,
          focusNode: widget.focusNode,
          textInputAction: widget.textInputAction,
          autofillHints: widget.autofillHints,
          textCapitalization: widget.textCapitalization,
          maxLength: widget.maxLength,
          autofocus: widget.autofocus,
          style: TextStyle(
            color: widget.enabled ? context.textPrimary : context.textDisabled,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            hintText: widget.hint,
            counterText: widget.counterText,
            prefixIcon: widget.prefixWidget ??
                (widget.prefixIcon != null
                    ? Icon(widget.prefixIcon,
                        size: 20, color: context.textSecondary)
                    : null),
            prefixText: widget.prefixText,
            suffixIcon: _resolvedSuffix,
          ),
        ),
      ],
    );
  }
}
