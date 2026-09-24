import 'package:flutter/material.dart';

import 'localization.dart';
import 'model.dart';
import 'security_service.dart';
import 'widgets.dart';

class VaultUnlockScreen extends StatefulWidget {
  const VaultUnlockScreen({
    super.key,
    required this.state,
    required this.onUnlocked,
    required this.onExitRequested,
  });

  final HealthAppState state;
  final VoidCallback onUnlocked;
  final Future<void> Function() onExitRequested;

  @override
  State<VaultUnlockScreen> createState() => _VaultUnlockScreenState();
}

class _VaultUnlockScreenState extends State<VaultUnlockScreen> {
  final _pin = TextEditingController();
  String _error = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.state.settings.biometricEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _biometric());
    }
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) widget.onExitRequested();
      },
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.health_and_safety_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 18),
                    LocalizedText(
                      AppText.get(widget.state.localeCode, 'appName'),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const LocalizedText(
                      'Медицинский сейф заблокирован',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    LocalizedTextField(
                      controller: _pin,
                      autofocus: !widget.state.settings.biometricEnabled,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      maxLength: 12,
                      decoration: InputDecoration(
                        labelText: 'PIN-код',
                        errorText: _error.isEmpty ? null : _error,
                        prefixIcon: const Icon(Icons.pin_outlined),
                      ),
                      onSubmitted: (_) => _unlockPin(),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _unlockPin,
                        icon: const Icon(Icons.lock_open_outlined),
                        label: const LocalizedText('Разблокировать'),
                      ),
                    ),
                    if (widget.state.settings.biometricEnabled) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _biometric,
                          icon: const Icon(Icons.fingerprint),
                          label: const LocalizedText('Системная биометрия'),
                        ),
                      ),
                    ],
                    if (_busy) ...[
                      const SizedBox(height: 14),
                      const LinearProgressIndicator(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _unlockPin() async {
    setState(() {
      _busy = true;
      _error = '';
    });
    final valid = await SecurityService.instance.verifyPin(
      _pin.text,
      widget.state.settings.pinHash,
      widget.state.settings.pinSalt,
    );
    if (!mounted) return;
    if (valid) {
      widget.onUnlocked();
      return;
    }
    setState(() {
      _busy = false;
      _error = 'Неверный PIN-код';
      _pin.clear();
    });
  }

  Future<void> _biometric() async {
    setState(() {
      _busy = true;
      _error = '';
    });
    final valid = await SecurityService.instance.authenticateBiometric();
    if (!mounted) return;
    if (valid) {
      widget.onUnlocked();
      return;
    }
    setState(() {
      _busy = false;
      _error = 'Системная проверка не выполнена';
    });
  }
}
