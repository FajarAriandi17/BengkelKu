import "package:flutter/material.dart";

import "../../core/motion/motion.dart";
import "../../core/theme/app_colors.dart";
import "../../core/theme/app_typography.dart";

enum AppButtonVariant { primary, secondary, text }

/// Tombol baku BengkelKu. State: default, pressed (scale), disabled, loading.
/// Menghormati Reduce Motion lewat [Motion.respect].
class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.loading = false,
    this.icon,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool loading;
  final IconData? icon;
  final String? semanticLabel;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final disabled = widget.onPressed == null || widget.loading;

    final bg = switch (widget.variant) {
      AppButtonVariant.primary => c.blue,
      AppButtonVariant.secondary => c.blueSoft,
      AppButtonVariant.text => Colors.transparent,
    };
    final fg = switch (widget.variant) {
      AppButtonVariant.primary => Colors.white,
      AppButtonVariant.secondary => c.blue,
      AppButtonVariant.text => c.blue,
    };

    return Semantics(
      button: true,
      enabled: !disabled,
      label: widget.semanticLabel ?? widget.label,
      child: GestureDetector(
        onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
        onTapUp: disabled ? null : (_) => setState(() => _pressed = false),
        onTapCancel: disabled ? null : () => setState(() => _pressed = false),
        onTap: disabled ? null : widget.onPressed,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: Motion.respect(context, Motion.micro),
          curve: Motion.respectCurve(context, Motion.easeOut),
          child: Opacity(
            opacity: disabled && !widget.loading ? 0.5 : 1,
            child: Container(
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: widget.loading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation(fg),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(widget.icon, color: fg, size: 20),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          widget.label,
                          style: AppTypography.label.copyWith(color: fg),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
