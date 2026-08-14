import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../catalog/catalog_repository.dart';
import '../ui/tv_text_dialog.dart';
import 'parent_biometrics.dart';
import 'parent_pin.dart';
import 'parent_session.dart';
import 'release_pin_policy.dart';

/// Shows PIN dialog (or uses active session / biometrics). Returns true if unlocked.
Future<bool> ensureParentUnlocked(
  BuildContext context,
  CatalogRepository repository, {
  bool grantSession = true,
}) async {
  if (ParentSession.isActive()) return true;

  final settings = await repository.load();
  final pinManager = ParentPinManager(
    failureCount: settings.failCount,
    lockedUntilMs: settings.lockedUntilMs,
  );
  final now = DateTime.now().millisecondsSinceEpoch;
  if (pinManager.isLockedOut(now)) {
    final secs = (pinManager.remainingLockoutMs(now) / 1000).ceil();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Locked out. Try again in ${secs}s.')),
      );
    }
    return false;
  }

  // Biometrics only when the parent explicitly opted in (never auto after PIN change).
  // Device unlock PIN must never open parent settings.
  final biometrics = ParentBiometrics();
  if (settings.pinChangedFromDefault &&
      settings.biometricUnlock &&
      await biometrics.canAuthenticate()) {
    final bioOk = await biometrics.authenticate();
    if (bioOk) {
      pinManager.registerSuccess();
      await repository.clearPinFailures();
      if (grantSession) ParentSession.grant();
      return true;
    }
    // Cancelled or failed — fall through to app PIN.
  }

  if (!context.mounted) return false;
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _PinDialog(
      repository: repository,
      pinManager: pinManager,
      pinSalt: settings.pinSalt,
      pinHash: settings.pinHash,
      rejectDefaultDevPin: ReleasePinPolicy.rejectDefaultDevPin(
        isDebugBuild: !kReleaseMode,
        releaseReady: settings.releaseReady,
        pinChangedFromDefault: settings.pinChangedFromDefault,
      ),
    ),
  );
  if (ok == true && grantSession) {
    ParentSession.grant();
  }
  return ok == true;
}

class _PinDialog extends StatefulWidget {
  const _PinDialog({
    required this.repository,
    required this.pinManager,
    required this.pinSalt,
    required this.pinHash,
    required this.rejectDefaultDevPin,
  });

  final CatalogRepository repository;
  final ParentPinManager pinManager;
  final String? pinSalt;
  final String? pinHash;
  final bool rejectDefaultDevPin;

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _controller = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final pin = _controller.text.trim();
    final now = DateTime.now().millisecondsSinceEpoch;
    final manager = widget.pinManager;
    manager.refreshLockout(now);
    if (manager.isLockedOut(now)) {
      if (mounted) Navigator.of(context).pop(false);
      return;
    }

    final matchesHash =
        await manager.verifyPinAsync(pin, widget.pinSalt, widget.pinHash);
    final blockedDefault = widget.rejectDefaultDevPin &&
        pin == ParentPinManager.defaultDevPin;
    if (matchesHash && !blockedDefault) {
      manager.registerSuccess();
      await widget.repository.clearPinFailures();
      await widget.repository.upgradePinHashIfNeeded(pin);
      if (mounted) Navigator.of(context).pop(true);
      return;
    }

    final locked = manager.registerFailure(now);
    await widget.repository.recordPinFailure(manager);
    if (!mounted) return;
    if (locked) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() {
      _busy = false;
      _error = blockedDefault
          ? 'Default PIN disabled. Use your new PIN.'
          : 'Wrong PIN';
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return TvTextDialog(
      title: const Text('Parent PIN'),
      submitLabel: 'Unlock',
      onCancel: () {
        if (!_busy) Navigator.of(context).pop(false);
      },
      onSubmit: _submit,
      fieldBuilder: (context, focuses, submitFromField) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              focusNode: focuses.first,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(ParentPinManager.maxPinLength),
              ],
              decoration: const InputDecoration(
                hintText: 'Enter PIN',
                helperText: 'Press Down for Unlock, or Select to submit',
              ),
              onSubmitted: (_) => submitFromField(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        );
      },
    );
  }
}
