import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../catalog/catalog_repository.dart';
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

  // Prefer Face ID / fingerprint / device credential when available.
  final biometrics = ParentBiometrics();
  if (await biometrics.canAuthenticate()) {
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
        manager.verifyPin(pin, widget.pinSalt, widget.pinHash);
    final blockedDefault = widget.rejectDefaultDevPin &&
        pin == ParentPinManager.defaultDevPin;
    if (matchesHash && !blockedDefault) {
      manager.registerSuccess();
      await widget.repository.clearPinFailures();
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
    return AlertDialog(
      title: const Text('Parent PIN'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(ParentPinManager.maxPinLength),
            ],
            decoration: const InputDecoration(
              hintText: 'Enter PIN',
            ),
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: const Text('Unlock'),
        ),
      ],
    );
  }
}
