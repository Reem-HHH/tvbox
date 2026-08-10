import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// D-pad key handling for TV text fields (arrow keys otherwise stay in the caret).
KeyEventResult handleTvTextFieldKeys(
  KeyEvent event, {
  required VoidCallback moveNext,
  VoidCallback? onSubmit,
}) {
  if (event is! KeyDownEvent) return KeyEventResult.ignored;
  final key = event.logicalKey;
  if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.tab) {
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    moveNext();
    return KeyEventResult.handled;
  }
  if (onSubmit != null &&
      (key == LogicalKeyboardKey.select ||
          key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter)) {
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    onSubmit();
    return KeyEventResult.handled;
  }
  return KeyEventResult.ignored;
}

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
    this.secondaryLabel,
    this.onSecondary,
  });

  final Widget title;

  /// Build the input. Use [fieldFocus] on the *last* (or only) TextField and call
  /// [submitFromField] from `onSubmitted` so remote Enter / IME Done works.
  /// For extra fields above, create FocusNodes with [handleTvTextFieldKeys]
  /// that move focus downward toward [fieldFocus].
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

  /// Optional middle action (e.g. Clear).
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  State<TvTextDialog> createState() => _TvTextDialogState();
}

class _TvTextDialogState extends State<TvTextDialog> {
  late final FocusNode _fieldFocus = FocusNode(
    onKeyEvent: (node, event) => handleTvTextFieldKeys(
      event,
      moveNext: _focusSubmit,
      onSubmit: _submit,
    ),
  );
  late final FocusNode _cancelFocus = FocusNode(onKeyEvent: _onActionKey);
  late final FocusNode _secondaryFocus = FocusNode(onKeyEvent: _onActionKey);
  late final FocusNode _submitFocus = FocusNode(onKeyEvent: _onActionKey);

  @override
  void dispose() {
    _fieldFocus.dispose();
    _cancelFocus.dispose();
    _secondaryFocus.dispose();
    _submitFocus.dispose();
    super.dispose();
  }

  void _focusSubmit() {
    _submitFocus.requestFocus();
  }

  void _submit() {
    if (widget.submitEnabled) widget.onSubmit();
  }

  KeyEventResult _onActionKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _fieldFocus.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final hasSecondary =
        widget.secondaryLabel != null && widget.onSecondary != null;
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
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    focusNode: _cancelFocus,
                    onPressed: widget.onCancel,
                    child: Text(widget.cancelLabel),
                  ),
                  if (hasSecondary)
                    TextButton(
                      focusNode: _secondaryFocus,
                      onPressed: widget.onSecondary,
                      child: Text(widget.secondaryLabel!),
                    ),
                  FilledButton(
                    focusNode: _submitFocus,
                    autofocus: false,
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
