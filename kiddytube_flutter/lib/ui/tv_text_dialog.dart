import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Alert-style text prompt that keeps Cancel / primary actions reachable
/// with D-pad on Android TV (TextField otherwise traps arrow keys).
class TvTextDialog extends StatefulWidget {
  const TvTextDialog({
    super.key,
    required this.title,
    required this.fieldBuilder,
    required this.onCancel,
    required this.onSubmit,
    this.submitLabel = 'Save',
    this.cancelLabel = 'Cancel',
    this.submitEnabled = true,
  });

  final Widget title;

  /// Build the input. Use [fieldFocus] on the TextField and call [submitFromField]
  /// from `onSubmitted` so remote Enter / IME Done works.
  final Widget Function(
    BuildContext context,
    FocusNode fieldFocus,
    VoidCallback submitFromField,
  ) fieldBuilder;

  final VoidCallback onCancel;
  final VoidCallback onSubmit;
  final String submitLabel;
  final String cancelLabel;
  final bool submitEnabled;

  @override
  State<TvTextDialog> createState() => _TvTextDialogState();
}

class _TvTextDialogState extends State<TvTextDialog> {
  late final FocusNode _fieldFocus = FocusNode(onKeyEvent: _onFieldKey);
  final FocusNode _submitFocus = FocusNode();

  @override
  void dispose() {
    _fieldFocus.dispose();
    _submitFocus.dispose();
    super.dispose();
  }

  void _submit() {
    if (widget.submitEnabled) widget.onSubmit();
  }

  KeyEventResult _onFieldKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    // Leave the field so Save / Unlock can be focused with the remote.
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.tab) {
      _submitFocus.requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _submit();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: widget.title,
      content: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FocusTraversalOrder(
              order: const NumericFocusOrder(1),
              child: widget.fieldBuilder(context, _fieldFocus, _submit),
            ),
            const SizedBox(height: 20),
            FocusTraversalOrder(
              order: const NumericFocusOrder(2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: widget.onCancel,
                    child: Text(widget.cancelLabel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    focusNode: _submitFocus,
                    onPressed: widget.submitEnabled ? _submit : null,
                    child: Text(widget.submitLabel),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
