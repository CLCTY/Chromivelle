import 'package:flutter/material.dart';

/// A rectangular control with visible ink and a short press/release motion.
class MotionTile extends StatefulWidget {
  const MotionTile({
    super.key,
    required this.child,
    required this.onTap,
    required this.color,
    required this.borderColor,
    this.selected = false,
    this.width,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final VoidCallback onTap;
  final Color color;
  final Color borderColor;
  final bool selected;
  final double? width;
  final EdgeInsets padding;

  @override
  State<MotionTile> createState() => _MotionTileState();
}

class _MotionTileState extends State<MotionTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reducedMotion
        ? Duration.zero
        : Duration(milliseconds: _pressed ? 100 : 240);
    final radius = BorderRadius.circular(
      _pressed
          ? 6
          : widget.selected
          ? 10
          : 14,
    );
    return Semantics(
      button: true,
      selected: widget.selected,
      child: AnimatedScale(
        scale: _pressed && !reducedMotion ? .94 : 1,
        duration: duration,
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: duration,
          curve: Curves.easeOutCubic,
          width: widget.width,
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: radius,
            border: Border.all(color: widget.borderColor),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: radius,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              borderRadius: radius,
              onHighlightChanged: (value) => setState(() => _pressed = value),
              onTap: widget.onTap,
              child: Padding(padding: widget.padding, child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Adds press motion to native buttons without intercepting their gestures.
class PressMotion extends StatefulWidget {
  const PressMotion({super.key, required this.child});
  final Widget child;
  @override
  State<PressMotion> createState() => _PressMotionState();
}

class _PressMotionState extends State<PressMotion> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed && !reducedMotion ? .96 : 1,
        duration: reducedMotion
            ? Duration.zero
            : Duration(milliseconds: _pressed ? 100 : 240),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
