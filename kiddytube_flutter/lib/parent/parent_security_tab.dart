part of 'parent_settings_screen.dart';

typedef _SessionCheck = bool Function();
typedef _Toast = void Function(String message);

class _SecurityTab extends StatelessWidget {
  const _SecurityTab({
    required this.settings,
    required this.repository,
    required this.sessionOk,
    required this.onChanged,
    required this.toast,
  });

  final CatalogSettings settings;
  final CatalogRepository repository;
  final _SessionCheck sessionOk;
  final Future<void> Function() onChanged;
  final _Toast toast;

  Future<void> _changePin(BuildContext context) async {
    if (!sessionOk()) return;
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => TvTextDialog(
        title: const Text('Change PIN'),
        submitLabel: 'Save',
        onCancel: () => Navigator.pop(ctx, false),
        onSubmit: () => Navigator.pop(ctx, true),
        fieldBuilder: (context, focuses, submitFromField) {
          return TextField(
            controller: controller,
            focusNode: focuses.first,
            obscureText: true,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(ParentPinManager.maxPinLength),
            ],
            decoration: const InputDecoration(
              hintText: 'New 4–8 digit PIN (not 2580)',
              border: OutlineInputBorder(),
              helperText: 'Press Down for Save, or Select to submit',
            ),
            onSubmitted: (_) => submitFromField(),
          );
        },
      ),
    );
    if (ok != true) {
      controller.dispose();
      return;
    }
    try {
      await repository.changePin(controller.text.trim());
      await onChanged();
      toast('PIN updated');
    } catch (e) {
      toast('$e');
    } finally {
      controller.dispose();
    }
  }

  Future<void> _toggleReleaseReady(bool value) async {
    if (!sessionOk()) return;
    try {
      await repository.setReleaseReady(value);
      await onChanged();
      toast(value ? 'Release ready on' : 'Release ready off');
    } catch (e) {
      toast('$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        Text(
          'Keep the kids area locked. Change the default PIN before shipping.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 20),
        Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              FocusTile(
                autofocus: true,
                onActivated: () => _changePin(context),
                child: ListTile(
                  leading: const Icon(Icons.pin_outlined),
                  title: const Text('Change PIN'),
                  subtitle: Text(
                    settings.pinChangedFromDefault
                        ? 'Custom PIN set'
                        : 'Default dev PIN is 2580 until changed',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _changePin(context),
                ),
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.verified_user_outlined),
                title: const Text('Release ready'),
                subtitle: Text(
                  settings.pinChangedFromDefault
                      ? 'Reject factory PIN after unlock'
                      : 'Change PIN first',
                ),
                value: settings.releaseReady,
                onChanged:
                    settings.pinChangedFromDefault ? _toggleReleaseReady : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HomeSyncTab extends StatefulWidget {
  const _HomeSyncTab({
    required this.settings,
    required this.repository,
    required this.sessionOk,
    required this.onChanged,
    required this.toast,
  });

  final CatalogSettings settings;
  final CatalogRepository repository;
  final _SessionCheck sessionOk;
  final Future<void> Function() onChanged;
  final _Toast toast;

  @override
  State<_HomeSyncTab> createState() => _HomeSyncTabState();
}

