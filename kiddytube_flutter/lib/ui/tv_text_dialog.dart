import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// D-pad key handling for TV text fields (arrow keys otherwise stay in the caret).
KeyEventResult handleTvTextFieldKeys(
  KeyEvent event, {
  required VoidCallback moveNext,
  VoidCallback? movePrevious,
  VoidCallback? onSubmit,
}) {
  if (event is! KeyDownEvent) return KeyEventResult.ignored;
  final key = event.logicalKey;
  if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.tab) {
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    moveNext();
    return KeyEventResult.handled;
  }
  if (movePrevious != null && key == LogicalKeyboardKey.arrowUp) {
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    movePrevious();
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
    this.fieldCount = 1,
    this.submitLabel = 'Save',
    this.cancelLabel = 'Cancel',
    this.submitEnabled = true,
    this.secondaryLabel,
    this.onSecondary,
  }) : assert(fieldCount >= 1);

  final Widget title;

  /// Number of text fields. Dialog owns stable [FocusNode]s for each.
  final int fieldCount;

  /// Build inputs. Use [fieldFocuses] in order (index 0 = first field).
  /// Call [submitFromField] from the last field's `onSubmitted`.
  final Widget Function(
    BuildContext context,
    List<FocusNode> fieldFocuses,
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
  late final List<FocusNode> _fieldFocuses;
  late final FocusNode _cancelFocus = FocusNode(onKeyEvent: _onActionKey);
  late final FocusNode _secondaryFocus = FocusNode(onKeyEvent: _onActionKey);
  late final FocusNode _submitFocus = FocusNode(onKeyEvent: _onActionKey);

  @override
  void initState() {
    super.initState();
    _fieldFocuses = List.generate(widget.fieldCount, _createFieldFocus);
  }

  FocusNode _createFieldFocus(int index) {
    return FocusNode(
      onKeyEvent: (node, event) => handleTvTextFieldKeys(
        event,
        moveNext: () => _moveFromField(index, forward: true),
        movePrevious: () => _moveFromField(index, forward: false),
        onSubmit: index == widget.fieldCount - 1 ? _submit : null,
      ),
    );
  }

  void _moveFromField(int index, {required bool forward}) {
    if (forward) {
      if (index + 1 < _fieldFocuses.length) {
        _fieldFocuses[index + 1].requestFocus();
      } else {
        _cancelFocus.requestFocus();
      }
      return;
    }
    if (index > 0) {
      _fieldFocuses[index - 1].requestFocus();
    }
  }

  @override
  void dispose() {
    for (final node in _fieldFocuses) {
      node.dispose();
    }
    _cancelFocus.dispose();
    _secondaryFocus.dispose();
    _submitFocus.dispose();
    super.dispose();
  }

  void _submit() {
    if (widget.submitEnabled) widget.onSubmit();
  }

  KeyEventResult _onActionKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _fieldFocuses.last.requestFocus();
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
              child: widget.fieldBuilder(context, _fieldFocuses, _submit),
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
                    // Keep focusable while busy; [_submit] no-ops if disabled.
                    onPressed: _submit,
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
