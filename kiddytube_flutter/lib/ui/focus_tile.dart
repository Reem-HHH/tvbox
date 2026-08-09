import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Focusable tile that scales on TV/D-pad focus and works with touch.
class FocusTile extends StatefulWidget {
  const FocusTile({
    super.key,
    required this.onActivated,
    required this.child,
    this.autofocus = false,
  });

  final VoidCallback onActivated;
  final Widget child;
  final bool autofocus;

  @override
  State<FocusTile> createState() => _FocusTileState();
}

class _FocusTileState extends State<FocusTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      autofocus: widget.autofocus,
      onShowFocusHighlight: (show) {
        if (_focused == show) return;
        setState(() => _focused = show);
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onActivated();
            return null;
          },
        ),
      },
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      child: GestureDetector(
        onTap: widget.onActivated,
        child: AnimatedScale(
          scale: _focused ? 1.04 : 1.0,
          duration: const Duration(milliseconds: 80),
          curve: Curves.easeOut,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _focused ? const Color(0xFF1565C0) : Colors.transparent,
                width: 3,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
