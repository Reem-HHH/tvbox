import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Focusable tile for TV/D-pad and touch.
/// Border-only focus ring (no blur/scale) to stay smooth on Android TV Impeller.
class FocusTile extends StatefulWidget {
  const FocusTile({
    super.key,
    required this.onActivated,
    required this.child,
    this.autofocus = false,
    this.focusNode,
  });

  final VoidCallback onActivated;
  final Widget child;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  State<FocusTile> createState() => _FocusTileState();
}

class _FocusTileState extends State<FocusTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      focusNode: widget.focusNode,
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
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _focused ? Colors.white : Colors.transparent,
              width: 3,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
